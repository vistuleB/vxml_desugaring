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

      let processed_text = process_single_content_with_context(
        current.content, s1, s2, prev_content, next_content
      )

      let new_content = vxml.BlamedContent(..current, content: processed_text)
      process_contents_with_neighbors(rest, s1, s2, [new_content, ..acc], index + 1)
    }
  }
}

fn process_single_content_with_context(
  content: String,
  s1: String,
  s2: String,
  prev_content: String,
  next_content: String
) -> String {
  content
  |> process_patterns_with_context(["\\begin{align*}", "\\begin{align}"], s1, prev_content, next_content, True)
  |> process_patterns_with_context(["\\end{align*}", "\\end{align}"], s2, prev_content, next_content, False)
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
      case is_begin {
        True -> reconstruct_begin_parts_with_context(parts, pattern, delimiter, prev_content, next_content, [])
        False -> reconstruct_end_parts_with_context(parts, pattern, delimiter, prev_content, next_content, [])
      }
    }
  }
}

fn reconstruct_begin_parts_with_context(
  parts: List(String),
  pattern: String,
  delimiter: String,
  prev_content: String,
  next_content: String,
  acc: List(String)
) -> String {
  case parts {
    [] -> string.join(list.reverse(acc), "")
    [single] -> string.join(list.reverse([single, ..acc]), "")
    [before, ..rest] -> {
      let is_first_pattern_in_content = acc == []
      let is_first_in_consecutive_group = case is_first_pattern_in_content {
        True -> {
          let combined = prev_content <> before
          !ends_with_begin_pattern(string.trim_end(combined)) && !string.ends_with(string.trim_end(combined), delimiter)
        }
        False -> !ends_with_begin_pattern(before)
      }

      let new_part = case is_first_in_consecutive_group {
        True -> before <> delimiter <> pattern
        False -> before <> pattern
      }

      reconstruct_begin_parts_with_context(rest, pattern, delimiter, prev_content, next_content, [new_part, ..acc])
    }
  }
}

fn reconstruct_end_parts_with_context(
  parts: List(String),
  pattern: String,
  delimiter: String,
  prev_content: String,
  next_content: String,
  acc: List(String)
) -> String {
  case parts {
    [] -> string.join(list.reverse(acc), "")
    [single] -> string.join(list.reverse([single, ..acc]), "")
    [before, ..rest] -> {
      let is_last_pattern_in_content = list.length(rest) == 1
      let is_last_in_consecutive_group = case rest {
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

      let new_part = case is_last_in_consecutive_group {
        True -> before <> pattern <> delimiter
        False -> before <> pattern
      }

      reconstruct_end_parts_with_context(rest, pattern, delimiter, prev_content, next_content, [new_part, ..acc])
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
                    \"$$\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}$$\"
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
                    \"$$\\begin{align*}\"
                    \"x = 1\"
                    \"\\end{align*}$$\"
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
                    \"$$\\begin{align}\"
                    \"\\begin{align}\"
                    \"x = 1\"
                    \"\\end{align}\"
                    \"\\end{align}$$\"
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
