import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn is_empty(child: VXML) {
  case child {
    T(_, lines) -> list.all(lines, fn(x) { string.is_empty(x.content) })
    _ -> False
  }
}

fn transform(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(_, tag, _, children) -> {
      case tag == "VerticalChunk" {
        True -> {
          case list.all(children, is_empty) {
            True -> Ok([])
            False -> Ok([node])
          }
        }

        False -> Ok([node])
      }
    }
  }
}

fn transform_factory(_param: InnerParam) -> infra.NodeToNodesTransform {
  transform(_)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

pub fn remove_empty_chunks() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_empty_chunks",
      option.None, 
      "..."
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
