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
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) -> {
      case list.contains(inner, tag), list.all(children, is_empty) {
        True, True -> Ok([])
        _, _ -> Ok([node])
      }
    }
    _ -> Ok([node])
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

type Param = List(String)

type InnerParam = List(String)

/// removes empty elements that contain only empty text nodes
pub fn remove_empty_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_empty_tags",
      stringified_param: option.None,
      general_description: "
/// removes empty elements that contain only empty text nodes
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
