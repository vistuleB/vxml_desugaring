import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, type LatexDelimiterPair, DoubleDollar, SingleDollar, BackslashParenthesis, BackslashSquareBracket} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, type BlamedContent}

fn opening_and_closing_string_for_pair(
  pair: LatexDelimiterPair
) -> #(String, String) {
  case pair {
    DoubleDollar -> #("$$", "$$")
    SingleDollar -> #("$", "$")
    BackslashParenthesis -> #("\\(", "\\)")
    BackslashSquareBracket -> #("\\[", "\\]")
  }
}

fn normalize_begin_end_align_transform(s1: String, s2: String) -> DesugarerTransform {
  let nodemap = fn(node: VXML) -> Result(VXML, DesugaringError) {
    case node {
      vxml.V(_, _, _, _) -> Ok(node)
      vxml.T(blame, blamed_contents) -> {
        let processed_contents = process_blamed_contents_for_align_delimiters(blamed_contents, s1, s2)
        Ok(vxml.T(blame, processed_contents))
      }
    }
  }

  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap)
}

fn process_blamed_contents_for_align_delimiters(
  contents: List(BlamedContent),
  s1: String,
  s2: String
) -> List(BlamedContent) {
  // process each content with awareness of its neighbors
  process_contents_with_neighbors(contents, s1, s2, [], 0)
}

fn process_contents_with_neighbors(
  contents: List(BlamedContent),
  s1: String,
  s2: String,
  acc: List(BlamedContent),
  index: Int
) -> List(BlamedContent) {
  case contents {
    [] -> list.reverse(acc)
    [current, ..rest] -> {
      let prev_content = case acc {
        [prev, ..] -> prev.content
        [] -> ""
      }

      let next_content = case rest {
        [next, ..] -> next.content
        [] -> ""
      }

      let processed_result = process_single_content_with_context(
        current, s1, s2, prev_content, next_content
      )

      process_contents_with_neighbors(rest, s1, s2, list.append(list.reverse(processed_result), acc), index + 1)
    }
  }
}

fn process_single_content_with_context(
  content: BlamedContent,
  s1: String,
  s2: String,
  prev_content: String,
  next_content: String
) -> List(BlamedContent) {
  let text = content.content

  let processed_text = text
    |> process_patterns_with_context(["\\begin{align*}", "\\begin{align}"], s1, prev_content, next_content, True)
    |> process_patterns_with_context(["\\end{align*}", "\\end{align}"], s2, prev_content, next_content, False)

  // check if delimiters need to be added as separate lines
  check_and_add_delimiters_as_lines(content, text, processed_text, s1, s2)
}



fn check_and_add_delimiters_as_lines(
  original_content: BlamedContent,
  original_text: String,
  processed_text: String,
  s1: String,
  s2: String
) -> List(BlamedContent) {
  let result = [vxml.BlamedContent(..original_content, content: processed_text)]

  // check if s1 was prepended
  case string.starts_with(processed_text, s1) && !string.starts_with(original_text, s1) {
    True -> {
      let without_s1 = string.drop_start(processed_text, string.length(s1))
      let delimiter_content = vxml.BlamedContent(..original_content, content: s1)
      let main_content = vxml.BlamedContent(..original_content, content: without_s1)
      [delimiter_content, main_content]
    }
    False -> {
      // check if s2 was appended
      case string.ends_with(processed_text, s2) && !string.ends_with(original_text, s2) {
        True -> {
          let without_s2 = string.drop_end(processed_text, string.length(s2))
          let delimiter_content = vxml.BlamedContent(..original_content, content: s2)
          let main_content = vxml.BlamedContent(..original_content, content: without_s2)
          [main_content, delimiter_content]
        }
        False -> result
      }
    }
  }
}

fn process_patterns_with_context(
  content: String,
  patterns: List(String),
  delimiter: String,
  prev_content: String,
  next_content: String,
  is_begin: Bool
) -> String {
  list.fold(patterns, content, fn(acc_content, pattern) {
    process_single_pattern_with_context(acc_content, pattern, delimiter, prev_content, next_content, is_begin)
  })
}

fn process_single_pattern_with_context(
  content: String,
  pattern: String,
  delimiter: String,
  prev_content: String,
  next_content: String,
  is_begin: Bool
) -> String {
  case string.contains(content, pattern) {
    False -> content
    True -> {
      let parts = string.split(content, pattern)
      reconstruct_parts_with_context(parts, pattern, delimiter, prev_content, next_content, [], is_begin)
    }
  }
}

fn reconstruct_parts_with_context(
  parts: List(String),
  pattern: String,
  delimiter: String,
  prev_content: String,
  next_content: String,
  acc: List(String),
  is_begin: Bool
) -> String {
  case parts {
    [] -> string.join(list.reverse(acc), "")
    [single] -> string.join(list.reverse([single, ..acc]), "")
    [before, ..rest] -> {
      let should_add_delimiter = case is_begin {
        True -> {
          let is_first_pattern_in_content = acc == []
          case is_first_pattern_in_content {
            True -> {
              let combined = prev_content <> before
              !ends_with_begin_pattern(string.trim_end(combined)) && !string.ends_with(string.trim_end(combined), delimiter)
            }
            False -> !ends_with_begin_pattern(before)
          }
        }
        False -> {
          let is_last_pattern_in_content = list.length(rest) == 1
          case rest {
            [after, .._more_rest] -> {
              let combined_after = case is_last_pattern_in_content {
                True -> after <> next_content
                False -> after
              }
              let trimmed_after = string.trim_start(combined_after)
              !starts_with_end_pattern(trimmed_after) && case is_last_pattern_in_content {
                True -> !string.starts_with(trimmed_after, delimiter)
                False -> True
              }
            }
            [] -> {
              let trimmed_next = string.trim_start(next_content)
              !starts_with_end_pattern(trimmed_next) && !string.starts_with(trimmed_next, delimiter)
            }
          }
        }
      }

      let new_part = case should_add_delimiter, is_begin {
        True, True -> before <> delimiter <> pattern
        True, False -> before <> pattern <> delimiter
        False, _ -> before <> pattern
      }

      reconstruct_parts_with_context(rest, pattern, delimiter, prev_content, next_content, [new_part, ..acc], is_begin)
    }
  }
}

fn ends_with_begin_pattern(text: String) -> Bool {
  let trimmed = string.trim_end(text)
  string.ends_with(trimmed, "\\begin{align}") || string.ends_with(trimmed, "\\begin{align*}")
}

fn starts_with_end_pattern(text: String) -> Bool {
  let trimmed = string.trim_start(text)
  string.starts_with(trimmed, "\\end{align}") || string.starts_with(trimmed, "\\end{align*}")
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  let #(s1, s2) = inner
  normalize_begin_end_align_transform(s1, s2)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(opening_and_closing_string_for_pair(param))
}

type Param = LatexDelimiterPair

type InnerParam = #(String, String)

const name = "normalize_begin_end_align"
const constructor = normalize_begin_end_align

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds delimiters around \\begin{align} and
/// \\end{align} if not already present
pub fn normalize_begin_end_align(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "

/// adds delimiters around \\begin{align} and
/// \\end{align} if not already present
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  [
    infra.AssertiveTestData(
      param: DoubleDollar,
      source:   "
                <> root
                  <>
                    \"Some text\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"More text\"
                ",
      expected: "
                <> root
                  <>
                    \"Some text\"
                    \"$$\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"$$\"
                    \"More text\"
                ",
    ),
    infra.AssertiveTestData(
      param: DoubleDollar,
      source:   "
                <> root
                  <>
                    \"Some text\"
                    \"\\begin{align*}\"
                    \"x = 1\"
                    \"\\end{align*}\"
                    \"More text\"
                ",
      expected: "
                <> root
                  <>
                    \"Some text\"
                    \"$$\"
                    \"\\begin{align*}\"
                    \"x = 1\"
                    \"\\end{align*}\"
                    \"$$\"
                    \"More text\"
                ",
    ),
    infra.AssertiveTestData(
      param: DoubleDollar,
      source:   "
                <> root
                  <>
                    \"Some text\"
                    \"\\begin{align}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align}\"
                    \"More text\"
                ",
      expected: "
                <> root
                  <>
                    \"Some text\"
                    \"$$\"
                    \"\\begin{align}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align}\"
                    \"$$\"
                    \"More text\"
                ",
    ),
    infra.AssertiveTestData(
      param: DoubleDollar,
      source:   "
                <> root
                  <>
                    \"Some text\"
                    \"\\begin{align*}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align*}\"
                    \"More text\"
                ",
      expected: "
                <> root
                  <>
                    \"Some text\"
                    \"$$\"
                    \"\\begin{align*}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align*}\"
                    \"$$\"
                    \"More text\"
                ",
    ),
    infra.AssertiveTestData(
      param: DoubleDollar,
      source:   "
                <> root
                  <>
                    \"Some text\"
                    \"$$\"
                    \"\\begin{align*}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align*}\"
                    \"$$\"
                    \"More text\"
                ",
      expected: "
                <> root
                  <>
                    \"Some text\"
                    \"$$\"
                    \"\\begin{align*}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align*}\"
                    \"$$\"
                    \"More text\"
                ",
    ),
    infra.AssertiveTestData(
      param: DoubleDollar,
      source:   "
                <> root
                  <>
                    \"Some text\"
                    \"$$\\begin{align*}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align*}$$\"
                    \"More text\"
                ",
      expected: "
                <> root
                  <>
                    \"Some text\"
                    \"$$\\begin{align*}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align*}$$\"
                    \"More text\"
                ",
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
