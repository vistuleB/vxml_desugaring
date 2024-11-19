import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import node_to_node_transforms/wrap_element_children_transform.{
  type WrapElementChildrenExtra, wrap_element_children_transform,
}
import vxml_parser.{type VXML}

pub fn wrap_element_children_desugarer(
  vxml: VXML,
  extra: WrapElementChildrenExtra,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(
    vxml,
    wrap_element_children_transform,
    extra,
  )
}
