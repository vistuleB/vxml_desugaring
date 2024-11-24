import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn build_blamed_attributes(
  blame,
  attributes: List(#(String, String)),
) -> List(BlamedAttribute) {
  attributes
  |> list.map(fn(attr) {
    BlamedAttribute(blame, attr |> pair.first, attr |> pair.second)
  })
}

fn add_attributes_param_transform(
  vxml: VXML,
  extra: #(List(String), List(#(String, String))),
) -> Result(VXML, DesugaringError) {
  let #(to, new_attributes) = extra
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, old_attributes, children) -> {
      case list.contains(to, tag) {
        True -> {
          Ok(V(
            blame,
            tag,
            list.flatten([
              old_attributes,
              build_blamed_attributes(blame, new_attributes),
            ]),
            children,
          ))
        }
        False -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(
  extra: #(List(String), List(#(String, String))),
) -> NodeToNodeTransform {
  add_attributes_param_transform(_, extra)
}

fn desugarer_factory(
  extra: #(List(String), List(#(String, String))),
) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
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
