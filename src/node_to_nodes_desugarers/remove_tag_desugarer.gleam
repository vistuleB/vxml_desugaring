import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import node_to_nodes_transforms/remove_tag_transform.{remove_tag_transform}
import vxml_parser.{type VXML}

pub fn remove_tag_desugarer(
  vxml: VXML,
  extra: List(String),
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(vxml, remove_tag_transform, extra)
}
