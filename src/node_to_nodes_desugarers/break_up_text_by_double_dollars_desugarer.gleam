import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import node_to_nodes_transforms/break_up_text_by_double_dollars_transform.{
  break_up_text_by_double_dollars_transform,
}
import writerly_parser.{type VXML}

pub fn break_up_text_by_double_dollars_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    break_up_text_by_double_dollars_transform,
    Nil,
  )
}
