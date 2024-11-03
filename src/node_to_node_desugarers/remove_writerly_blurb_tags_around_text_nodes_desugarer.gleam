import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import node_to_node_transforms/remove_writerly_blurb_tags_around_text_nodes_transform.{
  remove_writerly_blurb_tags_around_text_nodes_transform,
}
import vxml_parser.{type VXML}

pub fn remove_writerly_blurb_tags_around_text_nodes_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(
    vxml,
    remove_writerly_blurb_tags_around_text_nodes_transform,
    Nil,
  )
}
