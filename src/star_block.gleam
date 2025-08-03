import gleam/io
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer}

pub fn dashes(num: Int) -> String { string.repeat("-", num) }
pub fn spaces(num: Int) -> String { string.repeat(" ", num) }
pub fn dots(num: Int) -> String { string.repeat(".", num) }
pub fn threedots(num: Int) -> String { string.repeat("…", num) }

// ************************
// 2-column table printer
// ************************

pub fn two_column_maxes(lines: List(#(String, String))) {
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
}

pub fn two_column_table(
  lines: List(#(String, String)),
  col1: String,
  col2: String,
  indentation: Int,
) -> Nil {
  let #(max_col1, max_col2) = two_column_maxes(lines)
  let header_left = spaces(indentation) <> "|-"
  let left = spaces(indentation) <> "| "
  let one_line = fn(pair: #(String, String),  index: Int) {
    io.println(
        left
        <> pair.0
        <> case index % 2 {
          1 -> spaces(max_col1 - string.length(pair.0) + 2)
          _ -> spaces(max_col1 - string.length(pair.0) + 2)
        }
        <> "| "
        <> pair.1
        <> spaces(max_col2 - string.length(pair.1) + 2)
        <> "|"
    )
  }
  io.println(header_left <> dashes(max_col1 + 2) <> "|-" <> dashes(max_col2 + 2) <> "|")
  one_line(#(col1, col2), 0)
  io.println(header_left <> dashes(max_col1 + 2) <> "|-" <> dashes(max_col2 + 2) <> "|")
  list.index_map(lines, one_line)
  io.println(header_left <> dashes(max_col1 + 2) <> "|-" <> dashes(max_col2 + 2) <> "|")
}

// ************************
// 3-column table printer
// ************************

pub fn three_column_maxes(
  lines: List(#(String, String, String))
) -> #(Int, Int, Int) {
  list.fold(
    lines,
    #(0, 0, 0),
    fn(acc, pair) {
      #(
        int.max(acc.0, string.length(pair.0)),
        int.max(acc.1, string.length(pair.1)),
        int.max(acc.2, string.length(pair.2)),
      )
    }
  )
}

pub fn three_column_table(
  lines: List(#(String, String, String)),
  col1: String,
  col2: String,
  col3: String,
  indentation: Int,
) -> Nil {
  let maxes = three_column_maxes(lines)
  let padding = #(1, 2, 1)
  let header_left = spaces(indentation) <> "|-"
  let left = spaces(indentation) <> "| "

  let one_line = fn(triple: #(String, String, String), index: Int) {
    io.println(
      left
      <> triple.0
      <> spaces(maxes.0 - string.length(triple.0) + padding.0)
      <> "| "
      <> triple.1
      <> case index % 2 {
        1 -> dots(maxes.1 - string.length(triple.1) + padding.1)
        _ -> dots(maxes.1 - string.length(triple.1) + padding.1)
      }
      <> "| "
      <> triple.2
      <> spaces(maxes.2 - string.length(triple.2) + padding.2)
      <> "|"
    )
  }

  io.println(header_left <> dashes(maxes.0 + padding.0) <> "|-" <> dashes(maxes.1 + padding.1) <> "|-" <> dashes(maxes.2 + padding.2) <> "|")
  one_line(#(col1, col2, col3), 0)
  io.println(header_left <> dashes(maxes.0 + padding.0) <> "|-" <> dashes(maxes.1 + padding.1) <> "|-" <> dashes(maxes.2 + padding.2) <> "|")
  list.index_map(lines, one_line)
  io.println(header_left <> dashes(maxes.0 + padding.0) <> "|-" <> dashes(maxes.1 + padding.1) <> "|-" <> dashes(maxes.2 + padding.2) <> "|")
}

// ************************
// 4-column table printer
// ************************

pub fn four_column_maxes(
  lines: List(#(String, String, String, String))
) -> #(Int, Int, Int, Int) {
  list.fold(
    lines,
    #(0, 0, 0, 0),
    fn(acc, pair) {
      #(
        int.max(acc.0, string.length(pair.0)),
        int.max(acc.1, string.length(pair.1)),
        int.max(acc.2, string.length(pair.2)),
        int.max(acc.3, string.length(pair.3)),
      )
    }
  )
}

pub fn four_column_table(
  lines: List(#(String, String, String, String)),
  // col1: String,
  // col2: String,
  // col3: String,
  // col4: String,
  indentation: Int,
) -> Nil {
  let maxes = four_column_maxes(lines)
  let padding = #(1, 2, 1, 1)
  let header_left = spaces(indentation) <> "|-"
  let left = spaces(indentation) <> "| "

  let one_line = fn(tuple: #(String, String, String, String), index: Int) {
    io.println(
      left
      <> tuple.0
      <> spaces(maxes.0 - string.length(tuple.0) + padding.0)
      <> "| "
      <> tuple.1
      <> case index % 2 {
        1 -> dots(maxes.1 - string.length(tuple.1) + padding.1)
        _ if index >= 0 -> threedots(maxes.1 - string.length(tuple.1) + padding.1)
        _ -> spaces(maxes.1 - string.length(tuple.1) + padding.1)
      }
      <> "| "
      <> tuple.2
      <> spaces(maxes.2 - string.length(tuple.2) + padding.2)
      <> "| "
      <> tuple.3
      <> spaces(maxes.3 - string.length(tuple.3) + padding.3)
      <> "|"
    )
  }

  let assert [first, ..rest] = lines

  io.println(header_left <> dashes(maxes.0 + padding.0) <> "|-" <> dashes(maxes.1 + padding.1) <> "|-" <> dashes(maxes.2 + padding.2) <> "|-" <> dashes(maxes.3 + padding.3) <> "|")
  one_line(first, -1)
  io.println(header_left <> dashes(maxes.0 + padding.0) <> "|-" <> dashes(maxes.1 + padding.1) <> "|-" <> dashes(maxes.2 + padding.2) <> "|-" <> dashes(maxes.3 + padding.3) <> "|")
  list.index_map(rest, one_line)
  io.println(header_left <> dashes(maxes.0 + padding.0) <> "|-" <> dashes(maxes.1 + padding.1) <> "|-" <> dashes(maxes.2 + padding.2) <> "|-" <> dashes(maxes.3 + padding.3) <> "|")
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

  // let desugarer_description_lines = case string.is_empty(desugarer.docs) {
  //   True -> []
  //   False -> 
  //     desugarer.docs
  //     |> string.trim
  //     |> string.split("\n")
  //     |> list.map(fn(line) {
  //       case string.starts_with(line, "/// ") {
  //         True -> string.drop_start(line, 4)
  //         False -> line
  //       }
  //     })
  // }

  star_block(
    True,
    list.append(
      [
        "DESUGARER " <> ins(step),
        "",
        name_and_param,
        // "",
      ],
      // desugarer_description_lines,
      [],
    ),
    True,
  )
}
