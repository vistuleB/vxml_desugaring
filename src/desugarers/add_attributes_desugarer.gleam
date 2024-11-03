import desugarers/helpers/add_attributes_helpers.{
  type AddAttributesExtraArgs, add_attributes,
}
import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import vxml_parser.{type VXML}

pub fn add_attributes_desugarer(
  vxml: VXML,
  extra: AddAttributesExtraArgs,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(vxml, add_attributes, extra)
}
