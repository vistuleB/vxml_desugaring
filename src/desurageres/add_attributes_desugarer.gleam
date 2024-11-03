import desurageres/helpers/add_attributes_helpers.{type AddAttributesExtraArgs,add_attributes}
import vxml_parser.{type VXML}
import infastucture.{type  DesugaringError, depth_first_node_to_node_desugarer_many}

pub fn add_attributes_desugarer_many(vxmls: List(VXML), extra: AddAttributesExtraArgs) -> Result(List(VXML), DesugaringError) 
{
  depth_first_node_to_node_desugarer_many(
    vxmls,
    add_attributes,
    extra
  )
}