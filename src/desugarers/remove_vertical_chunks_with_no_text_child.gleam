import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodesTransform, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

fn is_text(child: VXML) {
  case child {
    T(_, _) -> True
    _ -> False
  }
}

pub fn remove_vertical_chunks_with_no_text_child_transform(
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

fn transform_factory() -> NodeToNodesTransform {
  remove_vertical_chunks_with_no_text_child_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory())
}

pub fn remove_vertical_chunks_with_no_text_child() -> Pipe {
  #(
    DesugarerDescription(
      "remove_vertical_chunks_with_no_text_child",
      option.None,
      "...",
    ),
    desugarer_factory(),
  )
}
