import infrastructure.{type DesugaringError, DesugaringError}
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

pub fn remove_vertical_chunks_around_single_children_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  infrastructure.depth_first_node_to_node_desugarer(
    vxml,
    remove_vertical_chunks_around_single_children_transform,
    Nil,
  )
}
