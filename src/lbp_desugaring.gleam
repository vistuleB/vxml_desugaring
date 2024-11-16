import desugarers_docs.{ type Pipeline}
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
import vxml_parser.{type VXML, Blame}
import writerly_parser.{assemble_blamed_lines}
import pipeline_debug.{print_pipeline_doc}

const ins = string.inspect

pub const path = "test/content"

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

pub fn desugar_from_pipeline(vxml: VXML, pipeline: Pipeline) -> Result(VXML, DesugaringError) {
  case pipeline {
      [] -> Ok(vxml)
      [#(_, des_fun), ..rest] -> {
        des_fun(vxml) |> 
          result.try(desugar_from_pipeline(_, rest))
      }
  }
} 

pub fn desugar(vxmls: List(VXML)) -> Result(VXML, DesugaringError) {
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

    case get_root(vxmls) {
      Ok(root) -> pipeline |> desugar_from_pipeline(root, _)
      Error(e) -> Error(e)
    }
    
}

pub fn main() {

  let assert Ok(assembled) = writerly_parser.assemble_blamed_lines(path)

  print_pipeline_doc(assembled)

  // let assert Ok(writerlys) =
  //   writerly_parser.parse_blamed_lines(assembled, False)
  // let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  // case desugar(vxmls) {
  //   Ok(desugared) ->
  //     vxml_parser.debug_print_vxml("(add attribute desugarer)", desugared)
  //   Error(err) -> io.println("there was a desugaring error: " <> ins(err))
  // }
}
