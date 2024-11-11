import simplifile
import merge_content.{merge_content}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import writerly_parser.{writerlys_to_vxmls, parse_string, type VXML} 
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
import node_to_nodes_transforms/split_delimiters_chunks_transform.{
  SplitDelimitersChunksExtraArgs,
}
import node_to_nodes_transforms/wrap_elements_by_blankline_transform.{
  WrapByBlankLineExtraArgs,
}

const ins = string.inspect

fn get_root(vxmls: List(VXML), path: String) -> Result(VXML, DesugaringError) {
  case vxmls {
    [root] -> Ok(root)
    _ ->
      Error(DesugaringError(
        blame: writerly_parser.Blame("", 0, []),
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

  get_root(vxmls, path)
  |> result.then(remove_writerly_blurb_tags_around_text_nodes_desugarer(_))
  |> result.then(add_attributes_desugarer(_, extra_1))
  |> result.then(break_up_text_by_double_dollars_desugarer(_))
  |> result.then(pair_double_dollars_together_desugarer(_))
  |> result.then(wrap_elements_by_blankline_desugarer(_, extra_2))
  |> result.then(split_vertical_chunks_desugarer(_))
  |> result.then(remove_vertical_chunks_around_single_children_desugarer(_))
  |> result.then(split_delimiters_chunks_desugarer(_, extra_3))
  |> result.then(split_delimiters_chunks_desugarer(_, extra_4))
}

pub fn main() {
  let path = "test/sample.vxml"
  let assert Ok(merged_content) = merge_content(["test/content"], "", -1)

  let assert Ok(_) = simplifile.write("test/output.emu", merged_content)
  let assert Ok(file) = simplifile.read("test/output.emu")
  let assert Ok(writerlys) = parse_string(file, "test/output.emu", True)
  
  let vxmls = writerlys_to_vxmls(writerlys)
  case desugar(vxmls, path) {
    Ok(desugared) -> {
      writerly_parser.debug_print_vxmls("(add attribute desugarer)", [desugared])
    }

    Error(e) -> {
      io.println("there was a desugaring error: " <> ins(e))
    }
  }

  // case writerly_parser.parse_file(path, "sample", False) {
  //   Ok(vxmls) -> {
  //     case desugar(vxmls, path) {
  //       Ok(desugared) -> {
  //         writerly_parser.debug_print_vxmls("(add attribute desugarer)", [desugared])
  //       }

  //       Error(e) -> {
  //         io.println("there was a desugaring error: " <> ins(e))
  //       }
  //     }
  //   }

  //   Error(e) ->
  //     io.println("there was a parsing error for " <> path <> ": " <> ins(e))
  // }
}
