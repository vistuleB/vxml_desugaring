import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import node_to_node_transforms/remove_vertical_chunks_around_single_children_transform.{
  remove_vertical_chunks_around_single_children_transform,
}
import writerly_parser.{type VXML}

pub fn remove_vertical_chunks_around_single_children_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(
    vxml,
    remove_vertical_chunks_around_single_children_transform,
    Nil,
  )
}
