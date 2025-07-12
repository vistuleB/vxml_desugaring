import gleam/io
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer}

pub fn dashes(num: Int) -> String { string.repeat("-", num) }
pub fn spaces(num: Int) -> String { string.repeat(" ", num) }

// ************************
// 2-column table printer
// ************************

pub fn two_column_table(
  lines: List(#(String, String)),
  col1: String,
  col2: String,
  indentation: Int,
) -> Nil {
  let #(max_col1, max_col2) = 
    list.fold(
      lines,
      #(0, 0),
      fn(acc, pair) {
        #(
          int.max(acc.0, string.length(pair.0)),
          int.max(acc.1, string.length(pair.1))
        )
      }
    )
  let header_left = spaces(indentation) <> "|-"
  let left = spaces(indentation) <> "| "
  let one_line = fn(s1: String, s2: String) {
    io.println(
        left
        <> s1
        <> spaces(max_col1 - string.length(s1) + 2)
        <> "| "
        <> s2
        <> spaces(max_col2 - string.length(s2) + 2)
        <> "|"
    )
  }
  io.println(header_left <> dashes(max_col1 + 2) <> "|-" <> dashes(max_col2 + 2) <> "|")
  one_line(col1, col2)
  io.println(header_left <> dashes(max_col1 + 2) <> "|-" <> dashes(max_col2 + 2) <> "|")
  list.each(lines, fn(pair) { one_line(pair.0, pair.1) })
  io.println(header_left <> dashes(max_col1 + 2) <> "|-" <> dashes(max_col2 + 2) <> "|")
}

// ************************
// pipeline 'star block' printer
// ************************

const star_line_length = 53

fn star_header() -> String {
  "/" <> string.repeat("*", star_line_length - 1) <> "\n"
}

fn star_footer() -> String {
  " " <> string.repeat("*", star_line_length - 1) <> "/\n"
}

fn star_line(content: String) -> String {
  let chars_left = star_line_length - { 3 + string.length(content) }
  " * "
  <> content
  <> case chars_left >= 1 {
    True -> string.repeat(" ", chars_left - 1) <> "*"
    False -> ""
  }
  <> "\n"
}

fn star_block(
  first_finger: Bool,
  lines: List(String),
  second_finger: Bool,
) -> String {
  case first_finger {
    True -> "👇\n"
    False -> ""
  }
  <> star_header()
  <> string.concat(list.map(lines, star_line))
  <> star_footer()
  <> case second_finger {
    True -> "👇\n"
    False -> ""
  }
}

pub fn desugarer_description_star_block(
  desugarer: Desugarer,
  step: Int,
) -> String {
  let name_and_param =
    desugarer.name
    <> case desugarer.stringified_param {
      Some(desc) ->
        " "
        <> ins(desc)
        |> string.drop_start(1)
        |> string.drop_end(1)
        |> string.replace("\\\"", "\"")
      None -> ""
    }

  let desugarer_description_lines = case string.is_empty(desugarer.docs) {
    True -> []
    False -> 
      desugarer.docs
      |> string.trim
      |> string.split("\n")
      |> list.map(fn(line) {
        case string.starts_with(line, "/// ") {
          True -> string.drop_start(line, 4)
          False -> line
        }
      })
  }

  star_block(
    True,
    list.append(
      [
        "DESUGARER " <> ins(step),
        "",
        name_and_param,
        "",
      ],
      desugarer_description_lines,
    ),
    True,
  )
}
