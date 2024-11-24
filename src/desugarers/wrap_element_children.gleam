import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
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

fn transform_factory(extra: #(List(String), String)) -> NodeToNodeTransform {
  wrap_element_children_transform(_, extra)
}

fn desugarer_factory(extra: #(List(String), String)) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

pub fn wrap_element_children_desugarer(extra: #(List(String), String)) -> Pipe {
  #(
    DesugarerDescription(
      "wrap_element_children_desugarer",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra),
  )
}
