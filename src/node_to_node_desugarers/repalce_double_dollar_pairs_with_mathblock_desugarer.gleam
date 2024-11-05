import vxml_parser.{type VXML}
import infrastructure.{depth_first_node_to_node_desugarer}
import node_to_node_transforms/repalce_double_dollar_pairs_with_mathblock_transform.{repalce_double_dollar_pairs_with_mathblock_transform}

pub fn repalce_double_dollar_pairs_with_mathblock_desugarer(
   vxml: VXML,
) {
    depth_first_node_to_node_desugarer(
      vxml,
      repalce_double_dollar_pairs_with_mathblock_transform,
      Nil
    )
}