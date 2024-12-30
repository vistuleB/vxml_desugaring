import gleam/list
import gleam/option.{None, Some}
import gleam/string
import infrastructure as infra

const ins = string.inspect

// ************************
// Pipeline printing
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

pub fn star_block(
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
  desugarer_desc: infra.DesugarerDescription,
  step: Int,
) -> String {
  let desugarer_name_and_extra =
    desugarer_desc.function_name
    <> case desugarer_desc.extra {
      Some(extra) ->
        " "
        <> ins(extra)
        |> string.drop_start(1)
        |> string.drop_end(1)
        |> string.replace("\\\"", "\"")
      None -> ""
    }

  let desugarer_description_lines = case
    string.is_empty(desugarer_desc.general_description)
  {
    True -> []
    False -> string.split(desugarer_desc.general_description, "\n")
  }

  star_block(
    True,
    list.append(
      ["DESUGARER " <> ins(step), "", desugarer_name_and_extra, ""],
      desugarer_description_lines,
    ),
    True,
  )
}
