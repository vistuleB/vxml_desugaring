import desurageres/helpers/add_attributes_helpers.{type AddAttributesExtraArgs,add_attributes}
import vxml_parser.{type VXML}
import infrastructure.{type  DesugaringError, depth_first_node_to_node_desugarer}

pub fn add_attributes_desugarer(vxml: VXML, extra: AddAttributesExtraArgs) -> Result(VXML, DesugaringError) 
{
  depth_first_node_to_node_desugarer(
    vxml,
    add_attributes,
    extra
  )
}