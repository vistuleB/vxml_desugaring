import vxml_parser.{type VXML, T, V, type BlamedAttribute as BlamedAttributeType, BlamedAttribute}
import helpers.{type  DesugaringError, depth_first_node_to_node_desugarer_many}
import gleam/list

pub type Attribute {
  Attribute(key: String, value: String)
}

pub type AddAttributesExtraArgs {
  AddAttributesExtraArgs(to: List(String), attributes: List(Attribute))
} 

fn add(existing_attributes: List(BlamedAttributeType), new_attributes: List(Attribute), blame) -> List(BlamedAttributeType) {
  case new_attributes {
    [] -> []
    [first, ..rest] -> {
      existing_attributes 
        |> list.append([BlamedAttribute(blame: blame, key: first.key , value: first.value)]) 
        |> list.append(add(existing_attributes, rest, blame))
    }
  }
}

fn add_attributes(vxml: VXML, _, extra: AddAttributesExtraArgs) -> Result(VXML, DesugaringError) {

  case vxml {
    T(_, _) -> Ok(vxml) 
    V(blame, tag, attributes, children) -> {
      case list.contains(extra.to, tag) {
        True -> {
          let updated_attributes = add(attributes, extra.attributes, blame)
          Ok(V(blame, tag, updated_attributes, children))
        }
        False -> Ok(vxml)
      }
      
    }
  }
}

pub fn add_attributes_desugarer_many(vxmls: List(VXML), extra: AddAttributesExtraArgs) -> Result(List(VXML), DesugaringError) 
{
  depth_first_node_to_node_desugarer_many(
    vxmls,
    add_attributes,
    extra
  )
}