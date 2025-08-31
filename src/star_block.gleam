import gleam/io
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer}
import on

pub fn dashes(num: Int) -> String { string.repeat("-", num) }
pub fn solid_dashes(num: Int) -> String { string.repeat("─", num) }
pub fn spaces(num: Int) -> String { string.repeat(" ", num) }
pub fn dots(num: Int) -> String { string.repeat(".", num) }
pub fn threedots(num: Int) -> String { string.repeat("…", num) }
pub fn twodots(num: Int) -> String { string.repeat("‥", num) }

pub fn how_many(
  singular: String,
  plural: String,
  count: Int,
) -> String {
  case count {
    1 -> "1 " <> singular
    _ -> ins(count) <> " " <> plural
  }
}

// **********************
// 2-column table printer
// **********************

pub fn two_column_maxes(
  lines: List(#(String, String))
) -> #(Int, Int) {
  list.fold(
    lines,
    #(0, 0),
    fn(acc, pair) {
      #(
        int.max(acc.0, string.length(pair.0)),
        int.max(acc.1, string.length(pair.1)),
      )
    }
  )
}

pub fn two_column_table(
  lines: List(#(String, String)),
) -> List(String) {
  let maxes = two_column_maxes(lines)
  let padding = #(2, 2)
  let one_line = fn(cols: #(String, String)) -> String {
    "│ " <> cols.0 <> spaces(maxes.0 - string.length(cols.0) + padding.0) <>
    "| " <> cols.1 <> spaces(maxes.1 - string.length(cols.1) + padding.1) <>
    "|"
  }
  let sds = #(
    solid_dashes(maxes.0 + padding.0),
    solid_dashes(maxes.1 + padding.1),
  )
  let assert [first, ..rest] = lines
  [
    [
      "┌─" <> sds.0 <> "┬─" <> sds.1 <> "┐",
      one_line(first),
      "├─" <> sds.0 <> "┼─" <> sds.1 <> "┤"
    ],
    list.map(rest, one_line),
    [
      "└─" <> sds.0 <> "┴─" <> sds.1 <> "┘"
    ],
  ]
  |> list.flatten
}

// **********************
// 4-column table printer
// **********************

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
) -> List(String) {
  let maxes = four_column_maxes(lines)
  let padding = #(1, 2, 1, 1)
  let one_line = fn(tuple: #(String, String, String, String), index: Int) -> String {
    "│ " <> tuple.0 <> spaces(maxes.0 - string.length(tuple.0) + padding.0) <>
    "│ " <> tuple.1 <> case index % 2 {
      1 -> dots(maxes.1 - string.length(tuple.1) + padding.1)
      _ if index >= 0 -> twodots(maxes.1 - string.length(tuple.1) + padding.1)
      _ -> spaces(maxes.1 - string.length(tuple.1) + padding.1)
    } <>
    "│ " <> tuple.2 <> spaces(maxes.2 - string.length(tuple.2) + padding.2) <>
    "│ " <> tuple.3 <> spaces(maxes.3 - string.length(tuple.3) + padding.3) <>
    "│"
  }
  let sds = #(
    solid_dashes(maxes.0 + padding.0),
    solid_dashes(maxes.1 + padding.1),
    solid_dashes(maxes.2 + padding.2),
    solid_dashes(maxes.3 + padding.3),
  )
  let assert [first, ..rest] = lines
  [
    [
      "┌─" <> sds.0 <> "┬─" <> sds.1 <> "┬─" <> sds.2 <> "┬─" <> sds.3 <> "┐",
      one_line(first, -1),
      "├─" <> sds.0 <> "┼─" <> sds.1 <> "┼─" <> sds.2 <> "┼─" <> sds.3 <> "┤"
    ],
    list.index_map(rest, one_line),
    [
      "└─" <> sds.0 <> "┴─" <> sds.1 <> "┴─" <> sds.2 <> "┴─" <> sds.3 <> "┘"
    ],
  ]
  |> list.flatten
}

pub fn print_lines_at_indent(
  lines: List(String),
  indent: Int,
) -> Nil {
  let margin = spaces(indent)
  list.each(lines, fn(l) {io.println(margin <> l)})
}

// ************************
// pipeline 'star block' printer
// ************************

pub fn name_and_param_string(
  desugarer: Desugarer,
  step_no: Int,
) -> String {
  ins(step_no)
  <> ". "
  <> desugarer.name
  <> case desugarer.stringified_param {
    Some(desc) ->
      " "
      <> ins(desc)
      |> string.drop_start(1)
      |> string.drop_end(1)
      |> string.replace("\\\"", "\"")
    None -> ""
  }
}

pub fn turn_into_paragraph(
  message: String,
  max_line_length: Int,
) -> List(String) {
  let len = string.length(message)
  use <- on.true_false(
    len < max_line_length,
    on_true: [message],
  )
  let shortest = max_line_length * 3 / 5
  let #(current_start, current_end, remaining) = #(
    string.slice(message, 0, shortest),
    string.slice(message, shortest, max_line_length - shortest),
    string.slice(message, max_line_length, len),
  )
  case string.split_once(current_end |> string.reverse, " ") {
    Ok(#(before, after)) -> [
      current_start <> {after |> string.reverse},
      ..turn_into_paragraph(
        { before |> string.reverse } <> remaining,
        max_line_length
      )
    ]
    _ -> [
      current_start <> current_end,
      ..turn_into_paragraph(remaining, max_line_length)
    ]
  }
}

pub fn padded_error_paragraph(
  message: String,
  max_line_length: Int,
  pad: String,
) -> List(String) {
  message
  |> turn_into_paragraph(max_line_length)
  |> list.index_map(
    fn(s, i) {
      case i > 0 {
        False -> s
        True -> pad <> s
      }
    }
  )
}

pub fn strip_quotes(
  string: String,
) -> String {
  case {
    string.starts_with(string, "") &&
    string.ends_with(string, "") &&
    string != ""
  } {
    True -> string |> string.drop_start(1) |> string.drop_end(1)
    False -> string
  }
}
