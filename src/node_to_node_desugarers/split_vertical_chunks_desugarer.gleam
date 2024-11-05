import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import node_to_node_transforms/split_vertical_chunks_transform.{
 split_vertical_chunks_transform
}
import vxml_parser.{type VXML}

pub fn split_vertical_chunks_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(vxml, split_vertical_chunks_transform, Nil)
}
