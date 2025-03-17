import gleam/option
import infrastructure.{ type Desugarer, type Pipe, Pipe, DesugarerDescription } as infra

fn transform_factory() -> infra.NodeToNodesTransform {
  infra.replace_regex_by_tag_param_transform_indexed_group_version(
    _,
    infra.unescaped_suffix_indexed_regex("\\$\\$"),
    "DoubleDollar",
  )
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory())
}

pub fn replace_double_dollars_by_tags() -> Pipe {
  Pipe(
    description: DesugarerDescription("replace_dd_by_tags", option.None, "..."),
    desugarer: desugarer_factory(),
  )
}
