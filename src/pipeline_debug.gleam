import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import infrastructure.{type DesugaringError, type Pipe, DesugaringError}
import vxml_parser.{
  type Blame, type BlamedLine, type VXML, Blame, BlamedLine, T, V,
}
import writerly_parser.{type Writerly}

const ins = string.inspect

const path = "test/sample.emu"

// ************************
// Writerly to blamed lines
// ************************
fn map_with_special_first(
  z: List(a),
  fn1: fn(a) -> b,
  fn2: fn(a) -> b,
) -> List(b) {
  case z {
    [] -> []
    [first, ..rest] -> fn1(first) |> list.prepend(list.map(rest, fn2), _)
  }
}

fn writerly_to_blamed_lines(t: Writerly, indent: Int) -> List(BlamedLine) {
  case t {
    writerly_parser.BlankLine(blame) -> [BlamedLine(blame, indent, "")]
    writerly_parser.Blurb(_, blamed_contents) -> {
      map_with_special_first(
        blamed_contents,
        fn(first) { BlamedLine(first.blame, indent, first.content) },
        fn(after_first) {
          BlamedLine(after_first.blame, indent, after_first.content)
        },
      )
    }
    writerly_parser.CodeBlock(blame, annotation, blamed_contents) -> {
      [BlamedLine(blame, indent, "```" <> annotation)]
      |> list.append(
        list.map(blamed_contents, fn(blamed_content) {
          BlamedLine(blame, indent, blamed_content.content)
        }),
      )
      |> list.append([BlamedLine(blame, indent, "```")])
    }

    writerly_parser.Tag(blame, tag_name, blamed_attributes, children) -> {
      let tag_blamed_line = BlamedLine(blame, indent, "|> " <> tag_name)
      let attributes_blamed_lines =
        list.map(blamed_attributes, fn(t) {
          BlamedLine(t.blame, indent + 4, t.key <> " " <> t.value)
        })
      let children_blamed_lines =
        writerlys_to_blamed_lines_internal(children, indent + 4)

      [tag_blamed_line, ..attributes_blamed_lines]
      |> list.append(children_blamed_lines)
    }
  }
}

fn writerlys_to_blamed_lines_internal(
  writerlys: List(Writerly),
  indent: Int,
) -> List(BlamedLine) {
  case writerlys {
    [] -> []
    [first, ..rest] -> {
      writerly_to_blamed_lines(first, indent)
      |> list.append(writerlys_to_blamed_lines_internal(rest, indent))
    }
  }
}

fn writerlys_to_blamed_lines(writerlys: List(Writerly)) -> List(BlamedLine) {
  writerlys_to_blamed_lines_internal(writerlys, 0)
}

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

fn vxmls_to_blamed_lines(vxmls: List(VXML)) -> List(BlamedLine) {
  vxmls_to_blamed_lines_internal(vxmls, 0)
}

// ************************
// pretty printing
// ************************

type MarginAnnotator =
  fn(Blame) -> String

fn header(longest_blame_length: Int) -> String {
  string.repeat("-", longest_blame_length + 20)
  <> "\n"
  <> "| Blame"
  <> string.repeat(" ", longest_blame_length + 4 - string.length("| Blame"))
  <> "##Content\n"
  <> string.repeat("-", longest_blame_length + 20)
  <> "\n"
}

fn footer(longest_blame_length: Int) -> String {
  string.repeat("-", longest_blame_length + 20) <> "\n"
}

fn get_longest_blame_length(lines: List(BlamedLine)) -> Int {
  case lines {
    [] -> 0
    [first, ..rest] -> {
      int.max(
        string.length(blame_to_string(first.blame)),
        get_longest_blame_length(rest),
      )
    }
  }
}

fn blame_to_string(blame: Blame) -> String {
  blame.filename <> ":" <> ins(blame.line_no)
}

fn pretty_print(lines: List(BlamedLine), annotator: MarginAnnotator) -> String {
  lines
  |> list.map(fn(x) {
    let BlamedLine(blame, indent, suffix) = x
    annotator(blame) <> string.repeat(" ", indent) <> suffix
  })
  |> string.join("\n")
  <> "\n"
}

fn pipeline_docs_annotator(max_length: Int) -> MarginAnnotator {
  fn(blame: Blame) {
    "| "
    <> blame_to_string(blame)
    <> string.repeat(
      " ",
      max_length + 4 - string.length("| " <> blame_to_string(blame)),
    )
    <> "##"
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
              |> string.drop_left(1)
              |> string.drop_right(1)
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
          <> header(max_length)
          <> vxml_to_blamed_lines(vxml, 0)
          |> pretty_print(pipeline_docs_annotator(max_length))
          <> footer(max_length)
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

  let lines = writerlys_to_blamed_lines(writerlys)
  let max_length = get_longest_blame_length(lines)

  let output =
    "\n"
    <> star_header()
    <> star_line("SOURCE")
    <> star_footer()
    <> "👇\n"
    <> header(max_length)
    <> lines
    |> pretty_print(pipeline_docs_annotator(max_length))
    <> footer(max_length)

  let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  let output =
    output
    <> "👇\n"
    <> star_header()
    <> star_line("PARSE WLY -> VXML")
    <> star_footer()
    <> "👇\n"
    <> header(max_length)
    <> vxmls_to_blamed_lines(vxmls)
    |> pretty_print(pipeline_docs_annotator(max_length))
    <> footer(max_length)

  let output =
    output
    <> case get_root(vxmls) {
      Ok(root) -> debug_pipeline(root, pipeline, 1, max_length)
      Error(e) -> e.message
    }

  output
}
