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
import vxml_parser.{type VXML, Blame, type BlamedLine}
import writerly_parser.{type Writerly}
const ins = string.inspect

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

// fn get_longest_blame_length(writerlys: List(Writerly)) {
//   case writerlys {
//     [] -> 0
//     [first, ..rest] -> {
//       let comments_length =  first.blame.comments 
//             |> list.map(fn(x) { string.length(x) } ) 
//             |> list.reduce(fn(acc, x) { acc + x })
//             |> result.unwrap(0)

//       let length = string.length(first.blame.filename) + comments_length

//       let rest_length = get_longest_blame_length(rest)

//       case int.compare(length, rest_length) {
//         order.Gt -> length
//         _ -> rest_length
//       }
//     }
//   }
// }

const pre_announce_pad_to = 60

const margin_announce_pad_to = 30

const path = "test/content"

fn header(){
    string.repeat("-", pre_announce_pad_to + margin_announce_pad_to + 10) <> "\n"
      <> string.pad_right("| Blame", pre_announce_pad_to, " ")
      <> string.pad_right("TAG", margin_announce_pad_to, " ")
      <> "##Content\n"
      <> string.repeat("-", pre_announce_pad_to + margin_announce_pad_to + 10) <> "\n"
} 
          
fn footer(){
  string.repeat("-", pre_announce_pad_to + margin_announce_pad_to + 10) <> "\n"
} 

pub fn debug_pipeline(vxml: VXML, pipeline: Pipeline, step: Int) {
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
              <> ins(io.print(header()))
              <> ins(vxml_parser.debug_print_vxml("", vxml))
              <> ins(io.println(footer()))
              <> debug_pipeline(vxml, rest, step + 1)
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

  let output = ins(io.print("// PIPELINE INTROSPECTION\n" 
               <> header()))
               <> ins(writerly_parser.debug_print_writerlys("| ", writerlys))
               <> ins(io.println(footer()))

  let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  let output = output 
                <> ins(io.print("// WLY -> VXML\n" <> header()))
                <> ins(vxml_parser.debug_print_vxmls("", vxmls))
                <> ins(io.println(footer()))

  let output = output <> case get_root(vxmls) {
      Ok(root) -> debug_pipeline(root, pipeline, 0)
      Error(e) -> e.message
    }

  output
}


pub fn print_pipeline_doc(assembled) {
  let extra_1 =
    AddAttributesExtraArgs(["Book", "Item"], [Attribute("label", "test")])

  let extra_2 =
    WrapByBlankLineExtraArgs(tags: ["MathBlock", "Image", "Table", "Exercises"])

  let extra_3 =
    SplitDelimitersChunksExtraArgs(
      open_delimiter: "__",
      close_delimiter: "__",
      tag_name: "CentralItalicDisplay",
    )

  let extra_4 =
    SplitDelimitersChunksExtraArgs(
      open_delimiter: "_|",
      close_delimiter: "|_",
      tag_name: "CentralDisplay",
    )
 
  let pipeline = [
    desugarers_docs.remove_writerly_blurb_tags_around_text_nodes_pipe(),
    desugarers_docs.add_attributes_pipe(extra_1),
    desugarers_docs.break_up_text_by_double_dollars_pipe(),
    desugarers_docs.pair_double_dollars_together_pipe(),
    desugarers_docs.wrap_elements_by_blankline_pipe(extra_2),
    desugarers_docs.split_vertical_chunks_pipe(),
    desugarers_docs.remove_vertical_chunks_around_single_children_pipe(),
    desugarers_docs.split_delimiters_chunks_pipe(extra_3),
    desugarers_docs.split_delimiters_chunks_pipe(extra_4),
    desugarers_docs.split_content_by_low_level_delimiters_pipe(),
  ]
  pipeline |> pipeline_introspection_lines2string(assembled, _)
}
