import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      case list.any(param, fn(pair) { tag == pair |> pair.first }) {
        False -> Ok([vxml])
        True -> {
          case
            list.any(children, fn(child) {
              case child {
                T(_, _) -> False
                V(_, child_tag, _, _) -> list.contains(param, #(tag, child_tag))
              }
            })
          {
            False -> Ok([vxml])
            True -> Ok(children)
          }
        }
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(#(String, String))
type InnerParam = Param

pub fn unwrap_tag_when_parent_of_tag(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "unwrap_tag_when_parent_of_tag",
      option.Some(param |> ins),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
