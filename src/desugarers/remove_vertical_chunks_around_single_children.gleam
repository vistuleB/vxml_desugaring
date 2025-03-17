import gleam/option
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, T, V}

fn remove_vertical_chunks_around_single_children_transform(
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

fn transform_factory() -> infra.NodeToNodeTransform {
  remove_vertical_chunks_around_single_children_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn remove_vertical_chunks_around_single_children_desugarer() -> Pipe {
  Pipe(
    description: DesugarerDescription("remove_vertical_chunks_around_single_children_desugarer", option.None, "..."),
    desugarer: desugarer_factory(),
  )
}
