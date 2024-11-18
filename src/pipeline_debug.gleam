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
import vxml_parser.{type VXML, type Blame, Blame, type BlamedLine}
import writerly_parser.{type Writerly}
const ins = string.inspect

const path = "test/content"

fn header(longest_blame_length: Int){
    string.repeat("-", longest_blame_length + 20) <> "\n"
      <> "| Blame"
      <> string.repeat(" ", longest_blame_length - string.length("| Blame") + 10 )
      <> "##Content\n"
      <> string.repeat("-", longest_blame_length + 20) <> "\n"
} 
          
fn footer(longest_blame_length: Int){
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

fn get_blame_length(blame: Blame ) {
   string.length(blame.filename) + string.length(ins(blame.line_no)) + 1
}

fn get_longest_blame_length(writerlys: List(Writerly)) {
  case writerlys {
    [] -> 0
    [first, ..rest] -> {
   
      let first_length = case first {
        writerly_parser.Tag(b, _, _, children) -> {
          let current_blamed_length = get_blame_length(b)
          let children_longest_length = get_longest_blame_length(children)

          case int.compare(current_blamed_length, children_longest_length) {
            order.Gt -> current_blamed_length
            _ -> children_longest_length
          }
        }
        _ -> get_blame_length(first.blame)
      }

      let rest_length = get_longest_blame_length(rest)

      case int.compare(first_length, rest_length) {
        order.Gt -> first_length
        _ -> rest_length
      }
    }
  }
}

fn margin_assembler(
  blame: vxml_parser.Blame,
  longest_blame_length: Int,
  margin: String,
) -> String {

  let blame_col = "| " <> blame.filename <> ":" <> ins(blame.line_no)
          
  let blame_col = blame_col <> string.repeat(" ", longest_blame_length - string.length(blame_col) + 10)

  blame_col <> "##" <> margin

}

fn writerly_content_to_string(
  t: Writerly,
  indentation: String,
  longest_blame_length: Int,
) {
  case t {
    writerly_parser.BlankLine(blame) ->
      margin_assembler( blame, longest_blame_length, "") <> "\n"

    writerly_parser.Blurb(_, blamed_contents) -> "\n"

    writerly_parser.CodeBlock(blame, annotation, blamed_contents) -> "\n"

    writerly_parser.Tag(blame, tag_name, blamed_attributes, children) -> {

      let attributes_list = list.map(blamed_attributes, fn(t) {
        {
          margin_assembler(
            t.blame,
            longest_blame_length,
            indentation <> "    ",
          )
          <> t.key
          <> " "
          <> t.value
        }
      })
      {
        margin_assembler(blame, longest_blame_length, indentation)
        <> "|>"
        <> " "
        <> tag_name
        <> "\n"
        <> string.join(attributes_list, "\n")
        <> "\n"
        <> writerlys_content_to_string_internal(
            children,
            indentation <> "    ",
            longest_blame_length,
          )
      }
    }
  }
}


fn writerlys_content_to_string_internal(writerlys: List(Writerly), identation: String, longest_blame_length: Int) -> String {
    case writerlys {
      [] -> ""
      [first, ..rest] -> {
        writerly_content_to_string(first, identation, longest_blame_length)
        <> writerlys_content_to_string_internal(rest, identation, longest_blame_length)
      }
    }
}

fn writerlys_content_to_string(writerlys: List(Writerly), longest_blame_length: Int) -> String {
  writerlys_content_to_string_internal(writerlys, "    ", longest_blame_length)
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

  let longest_blame_length = get_longest_blame_length(writerlys)

  let output = "// PIPELINE INTROSPECTION\n" 
               <> header(longest_blame_length)
               <> writerlys_content_to_string(writerlys, longest_blame_length)
               <> footer(longest_blame_length)

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