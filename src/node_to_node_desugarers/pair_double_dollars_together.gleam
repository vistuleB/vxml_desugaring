import infrastructure.{depth_first_node_to_node_desugarer}
import node_to_node_transforms/pair_double_dollars_together_transform.{
  pair_double_dollars_together_transform,
}
import vxml_parser.{type VXML}

pub fn pair_double_dollars_together_desugarer(vxml: VXML) {
  depth_first_node_to_node_desugarer(
    vxml,
    pair_double_dollars_together_transform,
    Nil,
  )
}
