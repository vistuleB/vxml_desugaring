import pipeline_constructor
import gleam/order
import gleam/int
import desugarers_docs.{ type Pipeline}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import infrastructure.{type DesugaringError, DesugaringError}
import node_to_node_transforms/add_attributes_transform.{
  type AddAttributesExtraArgs, AddAttributesExtraArgs, Attribute,
}
import node_to_nodes_transforms/split_delimiters_chunks_transform.{
  SplitDelimitersChunksExtraArgs,
}
import node_to_nodes_transforms/wrap_elements_by_blankline_transform.{
  WrapByBlankLineExtraArgs,
}
import vxml_parser.{type VXML, type Blame, Blame, type BlamedLine, BlamedLine}
import writerly_parser.{type Writerly}
const ins = string.inspect

const path = "test/content"

type MarginAnnotator = fn(Blame) -> String

fn header(longest_blame_length: Int) -> String {
    string.repeat("-", longest_blame_length + 20) <> "\n"
      <> "| Blame"
      <> string.repeat(" ", longest_blame_length + 4 - string.length("| Blame") )
      <> "##Content\n"
      <> string.repeat("-", longest_blame_length + 20) <> "\n"
} 
          
fn footer(longest_blame_length: Int) -> String {
  string.repeat("-", longest_blame_length + 20) <> "\n"
} 

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

fn get_longest_blame_length(lines: List(BlamedLine)) -> Int {
  case lines {
    [] -> 0
    [first, ..rest] -> {
      int.max(string.length(blame_to_string(first.blame)),  get_longest_blame_length(rest))
    }
  }
}

fn blame_to_string(blame: Blame) -> String {
  blame.filename <> ":" <> ins(blame.line_no)
}

fn writerly_to_blamed_lines(
  t: Writerly,
  indent: Int,
) -> List(BlamedLine) {
  case t {
    writerly_parser.BlankLine(blame) -> [BlamedLine(blame, indent, "")]
    writerly_parser.Blurb(blame, _) -> [BlamedLine(blame, indent, "")]
    writerly_parser.CodeBlock(blame, _, _) -> [BlamedLine(blame, indent, "")]

    writerly_parser.Tag(blame, tag_name, blamed_attributes, children) -> {

      let tag_blamed_line = BlamedLine(blame, indent, "|> " <> tag_name)
      let attributes_blamed_lines = list.map(blamed_attributes, fn(t) {
        BlamedLine(t.blame, indent + 1, t.key <> " " <> t.value)
      })
      let children_blamed_lines = writerlys_to_blamed_lines_internal(children, indent + 1)

      [tag_blamed_line, ..attributes_blamed_lines]
        |> list.append(children_blamed_lines)
    }
  }
}

fn writerlys_to_blamed_lines_internal(writerlys: List(Writerly), indent: Int) ->  List(BlamedLine) {
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
    "| " <>
    blame_to_string(blame) <>
    string.repeat(" ", max_length + 4 - string.length("| " <> blame_to_string(blame))) <>
    "##"
  }
}

pub fn debug_pipeline(vxml: VXML, pipeline: Pipeline, step: Int, longest_blame_length: Int) {
case pipeline {
      [] -> ""
      [#(desugarer_desc, desugarer_fun), ..rest] -> {

        let pipe_info = ins(io.print("// PIPELINE STEP " <> ins(step) <>"\n"))
                          <> ins(io.print("           " <> desugarer_desc.function_name <>"\n"))
                          <> ins(io.print("           " <> ins(desugarer_desc.extra) <>"\n"))
                          <> ins(io.print("           " <> ins(desugarer_desc.general_description) <>"\n"))

        case desugarer_fun(vxml) {
          Ok(vxml) -> {
            pipe_info
              <> ins(io.print(header(longest_blame_length)))
              <> ins(vxml_parser.debug_print_vxml("", vxml))
              <> ins(io.println(footer(longest_blame_length)))
              <> debug_pipeline(vxml, rest, step + 1, longest_blame_length)
          }
          Error(error) -> {
            pipe_info
              <> ins(io.print("FAILED ON: " <> error.blame.filename <> ":" <> ins(error.blame.line_no) <>"\n"))
              <> ins(io.print("MESSAGE: " <> error.message <>"\n"))
          }
        }
      }
    }
}

pub fn pipeline_introspection_lines2string(
  input: List(BlamedLine),
  pipeline: Pipeline
) ->  String
{

  let assert Ok(writerlys) =
    writerly_parser.parse_blamed_lines(input, False)

  let lines = writerlys_to_blamed_lines(writerlys)
  let max_length = get_longest_blame_length(lines)

  let output = "// PIPELINE INTROSPECTION\n" 
               <> header(max_length)
               <> writerlys 
                  |> writerlys_to_blamed_lines() 
                  |> pretty_print(pipeline_docs_annotator(max_length))
               <> footer(max_length)

  // let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  // let output = output 
  //               <> ins(io.print("// WLY -> VXML\n" <> header()))
  //               <> ins(vxml_parser.debug_print_vxmls("", vxmls))
  //               <> ins(io.println(footer()))

  // let output = output <> case get_root(vxmls) {
  //     Ok(root) -> debug_pipeline(root, pipeline, 0)
  //     Error(e) -> e.message
  //   }

  output
}