import gleam/list
import gleam/option.{None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Pipe} as infra

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
  pipe: Pipe,
  step: Int,
) -> String {
  let desugarer_name_and_param =
    pipe.desugarer_name
    <> case pipe.stringified_param {
      Some(desc) ->
        " "
        <> ins(desc)
        |> string.drop_start(1)
        |> string.drop_end(1)
        |> string.replace("\\\"", "\"")
      None -> ""
    }

  let desugarer_description_lines = case string.is_empty(pipe.docs) {
    True -> []
    False -> 
      pipe.docs
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
        desugarer_name_and_param,
        "",
      ],
      desugarer_description_lines,
    ),
    True,
  )
}
