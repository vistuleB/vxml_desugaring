import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import node_to_nodes_transforms/remove_vertical_chunks_with_no_text_child_transform.{
  remove_vertical_chunks_with_no_text_child_transform,
}
import vxml_parser.{type VXML}

pub fn remove_vertical_chunks_with_no_text_child_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    remove_vertical_chunks_with_no_text_child_transform,
    Nil,
  )
}
