import infrastructure.{type DesugaringError, depth_first_node_to_nodes_desugarer}
import node_to_nodes_transforms/wrap_elements_by_blankline_transform.{
  type WrapByBlankLineExtraArgs, wrap_elements_by_blankline_transform,
}
import vxml_parser.{type VXML}

pub fn wrap_elements_by_blankline_desugarer(
  vxml: VXML,
  extra: WrapByBlankLineExtraArgs,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_nodes_desugarer(
    vxml,
    wrap_elements_by_blankline_transform,
    extra,
  )
}
