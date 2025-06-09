import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(_, tag, _, children) -> {
      case tag == "VerticalChunk" {
        True ->
          case children {
            [child] -> Ok(child)
            _ -> Ok(node)
          }
        False -> Ok(node)
      }
    }
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// removes VerticalChunk tags that have only a single child
pub fn remove_vertical_chunks_around_single_children_desugarer() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_vertical_chunks_around_single_children_desugarer",
      stringified_param: option.None,
      general_description: "
/// removes VerticalChunk tags that have only a single child
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
