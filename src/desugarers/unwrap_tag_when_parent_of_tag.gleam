import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      case list.any(inner, fn(pair) { tag == pair |> pair.first }) {
        False -> Ok([vxml])
        True -> {
          case
            list.any(children, fn(child) {
              case child {
                T(_, _) -> False
                V(_, child_tag, _, _) -> list.contains(inner, #(tag, child_tag))
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(#(String, String))
//              ↖       ↖
//              parent  child
//              tag     tag

type InnerParam = Param

/// unwraps parent tag when it contains specified child tag
pub fn unwrap_tag_when_parent_of_tag(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "unwrap_tag_when_parent_of_tag",
      stringified_param: option.Some(ins(param)),
      general_description: "/// unwraps parent tag when it contains specified child tag",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}