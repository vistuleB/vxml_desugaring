import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn param_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      Ok(V(
        blame,
        tag,
        list.filter(attributes, fn(blamed_attribute) {
          !list.contains(extra, blamed_attribute.key)
        }),
        children,
      ))
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(String)

pub fn remove_attributes(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_attributes",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
