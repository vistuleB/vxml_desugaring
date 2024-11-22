import infrastructure.{type DesugaringError, DesugaringError}
import vxml_parser.{type VXML, T, V}

pub fn remove_writerly_blurb_tags_around_text_nodes_transform(
  node: VXML,
  _: Nil,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, _, children) -> {
      case tag == "WriterlyBlurb" {
        False -> Ok(node)
        True ->
          case children {
            [T(_, _) as first_child] -> Ok(first_child)
            [] ->
              Error(DesugaringError(
                blame,
                "WriterlyBlurb node without child in remove_writerly_blurb_tags_around_text_nodes",
              ))
            [_, ..] ->
              Error(DesugaringError(
                blame,
                "WriterlyBlurb node with > 1 child in remove_writerly_blurb_tags_around_text_nodes",
              ))
          }
      }
    }
  }
}
