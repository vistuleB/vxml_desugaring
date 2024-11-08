import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import node_to_nodes_transforms/split_delimiters_chunks_transform.{
  split_delimiters_chunks_transform, type SplitDelimitersChunksExtraArgs
}
import vxml_parser.{type VXML}

pub fn split_delimiters_chunks_desugarer(
  vxml: VXML,
  extra: SplitDelimitersChunksExtraArgs
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    split_delimiters_chunks_transform,
    extra,
  )
}
