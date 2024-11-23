import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError, depth_first_node_to_node_desugarer,
}
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

fn transform_factory() -> NodeToNodeTransform {
  fn(node) { remove_writerly_blurb_tags_around_text_nodes_transform(node, Nil) }
}

fn desugarer_factory() -> Desugarer {
  fn(vxml) { depth_first_node_to_node_desugarer(vxml, transform_factory()) }
}

pub fn remove_writerly_blurb_tags_around_text_nodes_desugarer() -> Pipe {
  #(
    DesugarerDescription(
      "remove_writerly_blurb_tags_around_text_nodes_desugarer",
      option.None,
      "...",
    ),
    desugarer_factory(),
  )
}
