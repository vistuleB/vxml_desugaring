import vxml_parser.{type VXML}
import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import desurageres/helpers/break_up_text_nodes_by_double_dollars_helpers.{break_up_text_nodes_by_double_dollars}

pub fn break_up_text_nodes_by_double_dollars_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    break_up_text_nodes_by_double_dollars,
    Nil
  )
}