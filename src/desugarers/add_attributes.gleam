import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, BlamedAttribute, T, V}

pub fn add_attributes_transform(
  vxml: VXML,
  extra: #(List(String), List(#(String, String))),
) -> Result(VXML, DesugaringError) {
  let #(to, new_attributes) = extra
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      case list.contains(to, tag) {
        True -> {
          let attributes_to_add =
            list.map(new_attributes, fn(attr) {
              let #(key, value) = attr
              BlamedAttribute(blame: blame, key: key, value: value)
            })
          let updated_attributes = list.flatten([attributes, attributes_to_add])
          Ok(V(blame, tag, updated_attributes, children))
        }
        False -> Ok(vxml)
      }
    }
  }
}

pub fn add_attributes_desugarer(
  vxml: VXML,
  extra: #(List(String), List(#(String, String))),
) -> Result(VXML, DesugaringError) {
  infrastructure.depth_first_node_to_node_desugarer(
    vxml,
    add_attributes_transform,
    extra,
  )
}
