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
  contents
  |> list.map(fn(blamed_content) {
    let processed_text = process_text_for_align_delimiters(blamed_content.content, s1, s2)
    vxml.BlamedContent(..blamed_content, content: processed_text)
  })
}

fn process_text_for_align_delimiters(text: String, s1: String, s2: String) -> String {
  text
  |> process_begin_align_delimiters(s1)
  |> process_end_align_delimiters(s2)
}

fn process_begin_align_delimiters(text: String, s1: String) -> String {
  process_align_pattern(text, "\\begin{align*}", s1, True)
  |> process_align_pattern("\\begin{align}", s1, True)
}

fn process_end_align_delimiters(text: String, s2: String) -> String {
  process_align_pattern(text, "\\end{align*}", s2, False)
  |> process_align_pattern("\\end{align}", s2, False)
}

fn process_align_pattern(text: String, pattern: String, delimiter: String, is_opening: Bool) -> String {
  case string.contains(text, pattern) {
    False -> text
    True -> {
      let parts = string.split(text, pattern)
      process_align_parts(parts, pattern, delimiter, is_opening, [])
    }
  }
}

fn process_align_parts(
  parts: List(String),
  pattern: String,
  delimiter: String,
  is_opening: Bool,
  acc: List(String)
) -> String {
  case parts {
    [] -> string.join(list.reverse(acc), "")
    [single] -> string.join(list.reverse([single, ..acc]), "")
    [before, ..rest] -> {
      let should_add_delimiter = case is_opening {
        True -> !text_ends_with_delimiter_ignoring_whitespace(before, delimiter)
        False -> case rest {
          [after, ..] -> !text_starts_with_delimiter_ignoring_whitespace(after, delimiter)
          [] -> False
        }
      }

      let new_part = case should_add_delimiter, is_opening {
        True, True -> before <> delimiter <> pattern
        True, False -> before <> pattern <> delimiter
        False, _ -> before <> pattern
      }

      process_align_parts(rest, pattern, delimiter, is_opening, [new_part, ..acc])
    }
  }
}

fn text_ends_with_delimiter_ignoring_whitespace(text: String, delimiter: String) -> Bool {
  let trimmed = string.trim_end(text)
  string.ends_with(trimmed, delimiter)
}

fn text_starts_with_delimiter_ignoring_whitespace(text: String, delimiter: String) -> Bool {
  let trimmed = string.trim_start(text)
  string.starts_with(trimmed, delimiter)
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
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
