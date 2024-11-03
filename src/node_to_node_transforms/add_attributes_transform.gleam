import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, BlamedAttribute, T, V}

pub type Attribute {
  Attribute(key: String, value: String)
}

pub type AddAttributesExtraArgs {
  AddAttributesExtraArgs(to: List(String), attributes: List(Attribute))
}

pub fn add_attributes_transform(
  vxml: VXML,
  _,
  extra: AddAttributesExtraArgs,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      case list.contains(extra.to, tag) {
        True -> {
          let attributes_to_add =
            list.map(extra.attributes, fn(attr) {
              BlamedAttribute(blame: blame, key: attr.key, value: attr.value)
            })
          let updated_attributes = list.flatten([attributes, attributes_to_add])
          Ok(V(blame, tag, updated_attributes, children))
        }
        False -> Ok(vxml)
      }
    }
  }
}
