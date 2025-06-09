import gleam/list
import gleam/option
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe } as infra
import vxml.{type BlamedContent, type VXML, BlamedContent, T, V}

fn content_is_nonempty(blamed_content: BlamedContent) {
  case blamed_content {
    BlamedContent(_, "") -> False
    _ -> True
  }
}

fn transform(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok([node])
    T(blame, lines) -> {
      let nonempty_lines = list.filter(lines, content_is_nonempty)
      case list.is_empty(nonempty_lines) {
        True -> Ok([])
        False -> Ok([T(blame, lines)])
      }
    }
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodesTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// removes text nodes that contain only empty strings
pub fn remove_empty_text_nodes() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_empty_text_nodes",
      stringified_param: option.None,
      general_description: "
/// removes text nodes that contain only empty strings
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
