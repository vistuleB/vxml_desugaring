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
      let new_lines = list.filter(lines, content_is_nonempty)
      case list.is_empty(new_lines) {
        True -> Ok([])
        False -> Ok([T(blame, new_lines)])
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

/// for each text node, removes each line whose
/// content is the empty string & destroys
/// text nodes that end up with 0 lines
pub fn remove_empty_lines() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_empty_lines",
      stringified_param: option.None,
      general_description: "
/// for each text node, removes each line whose
/// content is the empty string & destroys
/// text nodes that end up with 0 lines
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
