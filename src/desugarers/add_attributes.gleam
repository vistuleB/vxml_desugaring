import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, depth_first_node_to_node_desugarer,
}
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

fn transform_factory(
  extra: #(List(String), List(#(String, String))),
) -> NodeToNodeTransform {
  fn(node) { add_attributes_transform(node, extra) }
}

fn desugarer_factory(
  extra: #(List(String), List(#(String, String))),
) -> Desugarer {
  fn(vxml) {
    depth_first_node_to_node_desugarer(vxml, transform_factory(extra))
  }
}

pub fn add_attributes_desugarer(
  extra: #(List(String), List(#(String, String))),
) -> Pipe {
  #(
    DesugarerDescription(
      "add_attributes_desugarer",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra),
  )
}
