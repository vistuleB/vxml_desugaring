import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import node_to_nodes_transforms/split_content_by_low_level_delimiters_transform.{
  split_content_by_low_level_delimiters_transform
}
import vxml_parser.{type VXML}

pub fn split_content_by_low_level_delimiters_desugarer(
  vxml: VXML,
  //extra: SplitDelimitersChunksExtraArgs
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    split_content_by_low_level_delimiters_transform,
    Nil,
  )
}
