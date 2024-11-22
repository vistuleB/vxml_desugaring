import gleam/list
import infrastructure.{type DesugaringError, DesugaringError}
import vxml_parser.{type VXML, T, V}

fn is_text(child: VXML) {
  case child {
    T(_, _) -> True
    _ -> False
  }
}

pub fn remove_vertical_chunks_with_no_text_child_transform(
  node: VXML,
  _: Nil,
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
