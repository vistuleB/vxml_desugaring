import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, T, V}

pub type WrapElementChildrenExtra {
  WrapElementChildrenExtra(element_tags: List(String), wrap_with: String)
}

pub fn wrap_element_children_transform(
  vxml: VXML,
  _: List(VXML),
  extra: WrapElementChildrenExtra,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      case list.contains(extra.element_tags, tag) {
        True -> {
          let new_children =
            list.map(children, fn(x) { V(blame, extra.wrap_with, [], [x]) })
          Ok(V(blame, tag, attributes, new_children))
        }
        False -> Ok(vxml)
      }
    }
  }
}
