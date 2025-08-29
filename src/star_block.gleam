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

// ************************
// 2-column table printer
// ************************

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
  let one_line = fn(tuple: #(String, String)) -> String {
    "│ "
    <> tuple.0
    <> spaces(maxes.0 - string.length(tuple.0) + padding.0)
    <> "│ "
    <> tuple.1
    <> spaces(maxes.1 - string.length(tuple.1) + padding.1)
    <> "│ "
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
) -> List(String) {
  let maxes = three_column_maxes(lines)
  let padding = #(1, 1, 1)
  let one_line = fn(tuple: #(String, String, String)) -> String {
    "│ "
    <> tuple.0
    <> spaces(maxes.0 - string.length(tuple.0) + padding.0)
    <> "│ "
    <> tuple.1
    <> spaces(maxes.1 - string.length(tuple.1) + padding.1)
    <> "│ "
    <> tuple.2
    <> spaces(maxes.2 - string.length(tuple.2) + padding.2)
    <> "│ "
  }
  let sds = #(
    solid_dashes(maxes.0 + padding.0),
    solid_dashes(maxes.1 + padding.1),
    solid_dashes(maxes.2 + padding.2),
  )
  let assert [first, ..rest] = lines
  [
    [
      "┌─" <> sds.0 <> "┬─" <> sds.1 <> "┬─" <> sds.2 <> "┐",
      one_line(first),
      "├─" <> sds.0 <> "┼─" <> sds.1 <> "┼─" <> sds.2 <> "┤"
    ],
    list.map(rest, one_line),
    [
      "└─" <> sds.0 <> "┴─" <> sds.1 <> "┴─" <> sds.2 <> "┘"
    ],
  ]
  |> list.flatten
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
) -> List(String) {
  let maxes = four_column_maxes(lines)
  let padding = #(1, 2, 1, 1)
  let one_line = fn(tuple: #(String, String, String, String), index: Int) -> String {
    "│ "
    <> tuple.0
    <> spaces(maxes.0 - string.length(tuple.0) + padding.0)
    <> "│ "
    <> tuple.1
    <> case index % 2 {
      1 -> dots(maxes.1 - string.length(tuple.1) + padding.1)
      _ if index >= 0 -> twodots(maxes.1 - string.length(tuple.1) + padding.1)
      _ -> spaces(maxes.1 - string.length(tuple.1) + padding.1)
    }
    <> "│ "
    <> tuple.2
    <> spaces(maxes.2 - string.length(tuple.2) + padding.2)
    <> "│ "
    <> tuple.3
    <> spaces(maxes.3 - string.length(tuple.3) + padding.3)
    <> "│"
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

pub fn print_table_at_indent(
  lines: List(String),
  indent: Int,
) -> Nil {
  let margin = spaces(indent)
  list.each(
    lines,
    fn(l) {io.println(margin <> l)}
  )
}

// ************************
// pipeline 'star block' printer
// ************************

const star_line_length = 53

fn star_header() -> String {
  "/" <> string.repeat("*", star_line_length - 1)
}

fn star_footer() -> String {
  " " <> string.repeat("*", star_line_length - 1) <> "/"
}

fn star_line(content: String) -> String {
  let chars_left = star_line_length - { 3 + string.length(content) }
  " * "
  <> content
  <> case chars_left >= 1 {
    True -> string.repeat(" ", chars_left - 1) <> "*"
    False -> ""
  }
}

fn star_block(
  first_finger: Bool,
  lines: List(String),
  second_finger: Bool,
) -> List(String) {
  [
    case first_finger {
      True -> ["👇"]
      False -> []
    },
    [star_header()],
    list.map(lines, star_line),
    [star_footer()],
    case second_finger {
      True -> ["👇"]
      False -> []
    }
  ]
  |> list.flatten
}

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

pub fn desugarer_name_star_block(
  desugarer: Desugarer,
  step_no: Int,
) -> List(String) {
  let name_and_param = name_and_param_string(desugarer, step_no)

  star_block(
    True,
    [name_and_param],
    True,
  )
}

pub fn desugarer_description_star_block(
  desugarer: Desugarer,
  step_no: Int,
) -> List(String) {
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
        "DESUGARER " <> ins(step_no),
        "",
        name_and_param,
        "",
      ],
      desugarer_description_lines,
    ),
    True,
  )
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
  echo shortest
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
