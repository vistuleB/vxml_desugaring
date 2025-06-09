import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      case dict.get(inner, tag) {
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param |> infra.aggregate_on_first)
}

type Param =
  List(#(String, String))
//       ↖       ↖
//       parent  attribute
//       tag     to remove

type InnerParam =
  Dict(String, List(String))

/// removes specified attributes from specified parent tags
pub fn remove_attributes_for_parents(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_attributes_for_parents",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// removes specified attributes from specified parent tags
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}