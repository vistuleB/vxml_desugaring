import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn param_transform(vxml: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      case dict.get(param, tag) {
        Ok(attributes_to_remove) -> {
          Ok(V(
            blame,
            tag,
            list.filter(attributes, fn(blamed_attribute) {
              !list.contains(attributes_to_remove, blamed_attribute.key)
            }),
            children,
          ))
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

type Param =
  Dict(String, List(String))

fn extra_to_param(extra: Extra) -> Param {
  extra
  |> infra.aggregate_on_first
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Extra =
  List(#(String, String))

pub fn remove_attributes_for_parents(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_attributes_for_parents",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra |> extra_to_param),
  )
}
