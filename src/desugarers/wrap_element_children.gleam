import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, T, V}

pub fn wrap_element_children_transform(
  vxml: VXML,
  extra: #(List(String), String),
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      let #(element_tags, wrap_with) = extra
      case list.contains(element_tags, tag) {
        True -> {
          let new_children =
            list.map(children, fn(x) { V(blame, wrap_with, [], [x]) })
          Ok(V(blame, tag, attributes, new_children))
        }
        False -> Ok(vxml)
      }
    }
  }
}

pub fn wrap_element_children_desugarer(
  vxml: VXML,
  extra: #(List(String), String),
) -> Result(VXML, DesugaringError) {
  infrastructure.depth_first_node_to_node_desugarer(
    vxml,
    wrap_element_children_transform,
    extra,
  )
}
