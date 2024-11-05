

import gleam/io
import gleam/list
import gleam/result
import gleam/string
import infrastructure.{type DesugaringError, DesugaringError}
import node_to_node_desugarers/add_attributes_desugarer.{
  add_attributes_desugarer,
}
import node_to_node_desugarers/remove_writerly_blurb_tags_around_text_nodes_desugarer.{
  remove_writerly_blurb_tags_around_text_nodes_desugarer,
}
import node_to_node_transforms/add_attributes_transform.{
  type AddAttributesExtraArgs, AddAttributesExtraArgs, Attribute,
}
import node_to_nodes_desugarers/break_up_text_by_double_dollars_desugarer.{
  break_up_text_by_double_dollars_desugarer
}
import node_to_node_desugarers/repalce_double_dollar_pairs_with_mathblock_desugarer.{
  repalce_double_dollar_pairs_with_mathblock_desugarer
}

import node_to_nodes_desugarers/wrap_elements_by_blankline_desugarer.{
  wrap_elements_by_blankline_desugarer
}
import node_to_nodes_transforms/wrap_elements_by_blankline_transform.{WrapByBlankLineExtraArgs}
import node_to_node_desugarers/split_vertical_chunks_desugarer.{split_vertical_chunks_desugarer}

import vxml_parser.{type VXML}

const ins = string.inspect

fn get_root(vxmls: List(VXML), path: String) -> Result(VXML, DesugaringError) {
  case vxmls {
    [root] -> Ok(root)
    _ ->
      Error(DesugaringError(
        blame: vxml_parser.Blame("", 0, []),
        message: "found "
          <> ins(list.length)
          <> " != 1 root-level nodes in "
          <> path,
      ))
  }
}

pub fn desugar(vxmls: List(VXML), path) -> Result(VXML, DesugaringError) {
  let extra_1 =
    AddAttributesExtraArgs(["Section", "Item"], [Attribute("label", "test")])

  let extra_2 =
    WrapByBlankLineExtraArgs(tags: ["MathBlock", "Image", "Table", "Exercises"])

  get_root(vxmls, path)
  |> result.then(remove_writerly_blurb_tags_around_text_nodes_desugarer(_))
  |> result.then(add_attributes_desugarer(_, extra_1))
  |> result.then(break_up_text_by_double_dollars_desugarer(_))
  |> result.then(repalce_double_dollar_pairs_with_mathblock_desugarer(_))
  |> result.then(wrap_elements_by_blankline_desugarer(_, extra_2))
  |> result.then(split_vertical_chunks_desugarer(_))

}

pub fn main() {
  let path = "test/sample.vxml"

  case vxml_parser.parse_file(path, "sample", False) {
    Ok(vxmls) -> {
      case desugar(vxmls, path) {
        Ok(desugared) -> {
          vxml_parser.debug_print_vxmls("(add attribute desugarer)", [desugared])
        }

        Error(e) -> {
          io.println("there was a desugaring error: " <> ins(e))
        }
      }
    }

    Error(e) ->
      io.println("there was a parsing error for " <> path <> ": " <> ins(e))
  }
}
