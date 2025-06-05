import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn is_text(child: VXML) {
  case child {
    T(_, _) -> True
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
          case list.any(children, is_text) {
            True -> Ok([node])
            False -> Ok(children)
          }
        }

        False -> Ok([node])
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

/// unwraps VerticalChunk tags that contain no text children
pub fn unwrap_vertical_chunks_with_no_text_child() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "unwrap_vertical_chunks_with_no_text_child",
      stringified_param: option.Some(ins(Nil)),
      general_description: "/// unwraps VerticalChunk tags that contain no text children",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}