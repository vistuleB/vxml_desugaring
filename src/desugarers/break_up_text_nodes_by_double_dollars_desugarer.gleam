import desugarers/helpers/break_up_text_nodes_by_double_dollars_helpers.{
  break_up_text_nodes_by_double_dollars,
}
import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import vxml_parser.{type VXML}

pub fn break_up_text_nodes_by_double_dollars_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    break_up_text_nodes_by_double_dollars,
    Nil,
  )
}
