import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import node_to_node_transforms/add_attributes_transform.{
  type AddAttributesExtraArgs, add_attributes_transform,
}
import vxml_parser.{type VXML}

pub fn add_attributes_desugarer(
  vxml: VXML,
  extra: AddAttributesExtraArgs,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(vxml, add_attributes_transform, extra)
}
