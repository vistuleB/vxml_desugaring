import infrastructure.{type DesugaringError, depth_first_node_to_node_desugarer}
import node_to_node_transforms/wrap_math_with_no_break_transform.{
  wrap_math_with_no_break_transform,
}
import vxml_parser.{type VXML}

pub fn wrap_math_with_no_break_desugarer(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugarer(
    vxml,
    wrap_math_with_no_break_transform,
    Nil,
  )
}
