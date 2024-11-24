import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

fn remove_writerly_blurb_tags_around_text_nodes_transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, "WriterlyBlurb", _, children) ->
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
    _ -> Ok(node)
  }
}

fn transform_factory() -> NodeToNodeTransform {
  remove_writerly_blurb_tags_around_text_nodes_transform(_)
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
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
