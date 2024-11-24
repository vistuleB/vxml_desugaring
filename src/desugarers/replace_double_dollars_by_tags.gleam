import gleam/option
import infrastructure.{
  type Desugarer, type NodeToNodesTransform, type Pipe, DesugarerDescription,
} as infra

fn transform_factory() -> NodeToNodesTransform {
  infra.replace_regex_by_tag_param_transform(
    _,
    infra.unescaped_suffix_regex("\\$\\$"),
    "DoubleDollar",
  )
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory())
}

pub fn replace_double_dollars_by_tags() -> Pipe {
  #(
    DesugarerDescription("replace_dd_by_tags", option.None, "..."),
    desugarer_factory(),
  )
}
