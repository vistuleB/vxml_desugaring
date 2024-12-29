import blamedlines.{type Blame, type BlamedLine, Blame, BlamedLine}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import infrastructure.{type DesugaringError, type Pipe, DesugaringError}
import vxml_parser.{type VXML, T, V}
import writerly_parser

const ins = string.inspect

const path = "test/sample.emu"

// ************************
// VXML to blamed lines
// ************************

fn vxml_to_blamed_lines(vxml: VXML, indent: Int) -> List(BlamedLine) {
  case vxml {
    T(blame, lines) -> {
      [
        BlamedLine(blame, indent, "<>"),
        ..list.map(lines, fn(x) {
          BlamedLine(x.blame, indent + 4, "\"" <> x.content <> "\"")
        })
      ]
    }
    V(blame, tag_name, blamed_attributes, children) -> {
      let tag_blamed_line = BlamedLine(blame, indent, "<> " <> tag_name)
      let attributes_blamed_lines =
        list.map(blamed_attributes, fn(t) {
          BlamedLine(t.blame, indent + 4, t.key <> " " <> t.value)
        })
      let children_blamed_lines =
        vxmls_to_blamed_lines_internal(children, indent + 4)

      [tag_blamed_line, ..attributes_blamed_lines]
      |> list.append(children_blamed_lines)
    }
  }
}

fn vxmls_to_blamed_lines_internal(
  vxmls: List(VXML),
  indent: Int,
) -> List(BlamedLine) {
  case vxmls {
    [] -> []
    [first, ..rest] -> {
      vxml_to_blamed_lines(first, indent)
      |> list.append(vxmls_to_blamed_lines_internal(rest, indent))
    }
  }
}

// ************************
// Pipeline printing
// ************************

fn get_root(vxmls: List(VXML)) -> Result(VXML, DesugaringError) {
  case vxmls {
    [root] -> Ok(root)
    _ ->
      Error(DesugaringError(
        blame: Blame("", 0, []),
        message: "found "
          <> ins(list.length)
          <> " != 1 root-level nodes in "
          <> path,
      ))
  }
}

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

pub fn debug_pipeline(
  vxml: VXML,
  pipeline: List(Pipe),
  step: Int,
  max_length: Int,
) -> String {
  case pipeline {
    [] -> ""
    [#(desugarer_desc, desugarer_fun), ..rest] -> {
      let pipe_info =
        "👇\n"
        <> star_header()
        <> star_line("DESUGARER " <> ins(step))
        <> star_line("")
        <> star_line(
          desugarer_desc.function_name
          <> case desugarer_desc.extra {
            Some(extra) ->
              " "
              <> ins(extra)
              |> string.drop_start(1)
              |> string.drop_end(1)
              |> string.replace("\\\"", "\"")
            None -> ""
          },
        )
        <> {
          case string.is_empty(desugarer_desc.general_description) {
            True -> ""
            False ->
              star_line("")
              <> {
                string.split(desugarer_desc.general_description, "\n")
                |> list.map(star_line)
                |> string.join("")
              }
          }
        }
        <> star_footer()
        <> "👇\n"

      case desugarer_fun(vxml) {
        Ok(vxml) -> {
          pipe_info
          <> vxml_parser.debug_vxml_to_string("", vxml)
          <> debug_pipeline(vxml, rest, step + 1, max_length)
        }

        Error(error) -> {
          pipe_info
          <> "FAILED ON: "
          <> error.blame.filename
          <> ":"
          <> ins(error.blame.line_no)
          <> "\n"
          <> "MESSAGE: "
          <> error.message
          <> "\n"
        }
      }
    }
  }
}

// ************************
// Main function
// ************************

pub fn pipeline_introspection_lines2string(
  input: List(BlamedLine),
  pipeline: List(Pipe),
) -> String {
  let assert Ok(writerlys) = writerly_parser.parse_blamed_lines(input, False)

  let output =
    "\n"
    <> star_header()
    <> star_line("SOURCE")
    <> star_footer()
    <> "👇\n"
    <> writerly_parser.debug_writerlys_to_string("", writerlys)

  let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  let output =
    output
    <> "👇\n"
    <> star_header()
    <> star_line("PARSE WLY -> VXML")
    <> star_footer()
    <> "👇\n"
    <> vxml_parser.debug_vxmls_to_string("", vxmls)

  let output =
    output
    <> case get_root(vxmls) {
      Ok(root) -> debug_pipeline(root, pipeline, 1, 40)
      Error(e) -> e.message
    }

  output
}
