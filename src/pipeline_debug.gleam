import desugarers_docs.{type Pipeline}
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import infrastructure.{type DesugaringError, DesugaringError}
import vxml_parser.{
  type Blame, type BlamedLine, type VXML, Blame, BlamedLine, T, V,
}
import writerly_parser.{type Writerly}

const ins = string.inspect

const path = "test/content"

// ************************
// Writerly to blamed lines
// ************************
fn writerly_to_blamed_lines(t: Writerly, indent: Int) -> List(BlamedLine) {
  case t {
    writerly_parser.BlankLine(blame) -> [BlamedLine(blame, indent, "")]
    writerly_parser.Blurb(blame, _) -> [BlamedLine(blame, indent, "")]
    writerly_parser.CodeBlock(blame, _, _) -> [BlamedLine(blame, indent, "")]

    writerly_parser.Tag(blame, tag_name, blamed_attributes, children) -> {
      let tag_blamed_line = BlamedLine(blame, indent, "|> " <> tag_name)
      let attributes_blamed_lines =
        list.map(blamed_attributes, fn(t) {
          BlamedLine(t.blame, indent + 1, t.key <> " " <> t.value)
        })
      let children_blamed_lines =
        writerlys_to_blamed_lines_internal(children, indent + 1)

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
          BlamedLine(x.blame, indent + 1, "\"" <> x.content <> "\"")
        })
      ]
    }
    V(blame, tag_name, blamed_attributes, children) -> {
      let tag_blamed_line = BlamedLine(blame, indent, "<> " <> tag_name)
      let attributes_blamed_lines =
        list.map(blamed_attributes, fn(t) {
          BlamedLine(t.blame, indent + 1, t.key <> " " <> t.value)
        })
      let children_blamed_lines =
        vxmls_to_blamed_lines_internal(children, indent + 1)

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
    annotator(blame) <> string.repeat(" ", indent * 4) <> suffix
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

pub fn debug_pipeline(
  vxml: VXML,
  pipeline: Pipeline,
  step: Int,
  max_length: Int,
) -> String {
  case pipeline {
    [] -> ""
    [#(desugarer_desc, desugarer_fun), ..rest] -> {
      let pipe_info =
        "// PIPELINE STEP "
        <> ins(step)
        <> "\n"
        <> "           "
        <> desugarer_desc.function_name
        <> "\n"
        <> "           "
        <> ins(desugarer_desc.extra)
        <> "\n"
        <> "           "
        <> desugarer_desc.general_description
        <> "\n"

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
  pipeline: Pipeline,
) -> String {
  let assert Ok(writerlys) = writerly_parser.parse_blamed_lines(input, False)

  let lines = writerlys_to_blamed_lines(writerlys)
  let max_length = get_longest_blame_length(lines)

  let output =
    "// PIPELINE INTROSPECTION\n"
    <> header(max_length)
    <> lines
    |> pretty_print(pipeline_docs_annotator(max_length))
    <> footer(max_length)

  let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  let output =
    output
    <> "// WLY -> VXML\n"
    <> header(max_length)
    <> vxmls_to_blamed_lines(vxmls)
    |> pretty_print(pipeline_docs_annotator(max_length))
    <> ins(io.println(footer(max_length)))

  let output =
    output
    <> case get_root(vxmls) {
      Ok(root) -> debug_pipeline(root, pipeline, 0, max_length)
      Error(e) -> e.message
    }

  output
}
