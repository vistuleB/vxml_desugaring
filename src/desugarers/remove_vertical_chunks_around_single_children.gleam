import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError, depth_first_node_to_node_desugarer,
}
import vxml_parser.{type VXML, T, V}

pub fn remove_vertical_chunks_around_single_children_transform(
  node: VXML,
  _: Nil,
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

fn transform_factory() -> NodeToNodeTransform {
  fn(node) {
    remove_vertical_chunks_around_single_children_transform(node, Nil)
  }
}

fn desugarer_factory() -> Desugarer {
  fn(vxml) { depth_first_node_to_node_desugarer(vxml, transform_factory()) }
}

pub fn remove_vertical_chunks_around_single_children_desugarer() -> Pipe {
  #(
    DesugarerDescription(
      "remove_vertical_chunks_around_single_children_desugarer",
      option.None,
      "...",
    ),
    desugarer_factory(),
  )
}
