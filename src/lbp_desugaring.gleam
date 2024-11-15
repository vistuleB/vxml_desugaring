import desugarers_docs.{ type Pipeline}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import infrastructure.{type DesugaringError, DesugaringError}

import node_to_node_desugarers/add_attributes_desugarer.{
  add_attributes_desugarer,
}
import node_to_node_desugarers/pair_double_dollars_together_desugarer.{
  pair_double_dollars_together_desugarer,
}
import node_to_node_desugarers/remove_vertical_chunks_around_single_children_desugarer.{
  remove_vertical_chunks_around_single_children_desugarer,
}
import node_to_node_desugarers/remove_writerly_blurb_tags_around_text_nodes_desugarer.{
  remove_writerly_blurb_tags_around_text_nodes_desugarer,
}
import node_to_node_desugarers/split_vertical_chunks_desugarer.{
  split_vertical_chunks_desugarer,
}
import node_to_node_transforms/add_attributes_transform.{
  type AddAttributesExtraArgs, AddAttributesExtraArgs, Attribute,
}
import node_to_nodes_desugarers/break_up_text_by_double_dollars_desugarer.{
  break_up_text_by_double_dollars_desugarer,
}
import node_to_nodes_desugarers/split_delimiters_chunks_desugarer.{
  split_delimiters_chunks_desugarer,
}
import node_to_nodes_desugarers/wrap_elements_by_blankline_desugarer.{
  wrap_elements_by_blankline_desugarer,
}
import node_to_nodes_desugarers/split_content_by_low_level_delimiters_desugarer.{
  split_content_by_low_level_delimiters_desugarer
}

import node_to_nodes_transforms/split_delimiters_chunks_transform.{
  SplitDelimitersChunksExtraArgs,
}
import node_to_nodes_transforms/wrap_elements_by_blankline_transform.{
  WrapByBlankLineExtraArgs,
}
import vxml_parser.{type VXML, Blame, type BlamedLine}
import writerly_parser
const ins = string.inspect

fn get_root(vxmls: List(VXML), path: String) -> Result(VXML, DesugaringError) {
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

pub fn desugar(vxmls: List(VXML), path: String) -> Result(VXML, DesugaringError) {
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


  case get_root(vxmls, path) {
    Ok(root) -> {
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
      pipeline |> desugar_from_pipeline(root, _)
    }
    Error(e) -> Error(e)
  }
  
  

  // get_root(vxmls, path)
  // |> result.then(remove_writerly_blurb_tags_around_text_nodes_desugarer(_))
  // |> result.then(add_attributes_desugarer(_, extra_1))
  // |> result.then(break_up_text_by_double_dollars_desugarer(_))
  // |> result.then(pair_double_dollars_together_desugarer(_))
  // |> result.then(wrap_elements_by_blankline_desugarer(_, extra_2))
  // |> result.then(split_vertical_chunks_desugarer(_))
  // |> result.then(remove_vertical_chunks_around_single_children_desugarer(_))
  // |> result.then(split_delimiters_chunks_desugarer(_, extra_3))
  // |> result.then(split_delimiters_chunks_desugarer(_, extra_4))
  // |> result.then(split_content_by_low_level_delimiters_desugarer(_))


}

pub fn main() {
  let path = "test/content"

  let assert Ok(assembled) = writerly_parser.assemble_blamed_lines(path)
  //pipeline_introspection_lines2string(assembled, pipeline)
  let assert Ok(writerlys) =
    writerly_parser.parse_blamed_lines(assembled, False)
  let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  case desugar(vxmls, path) {
    Ok(desugared) ->
      vxml_parser.debug_print_vxml("(add attribute desugarer)", desugared)
    Error(err) -> io.println("there was a desugaring error: " <> ins(err))
  }
}
