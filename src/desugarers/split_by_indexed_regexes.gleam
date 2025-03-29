import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type Pipe, DesugarerDescription, Pipe} as infra
import indexed_regex_splitting as rs

fn transform_factory(extras: Extra) -> infra.NodeToNodesFancyTransform {
  let #(regexes_and_tags, forbidden_parents) = extras
  rs.replace_regexes_by_tags_param_transform_indexed_group_version(
    _,
    regexes_and_tags,
  )
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(extras: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extras))
}

type Extra =
  #(List(#(rs.RegexWithIndexedGroup, String)), List(String))

pub fn split_by_indexed_regexes(extras: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "split_by_indexed_regexes",
      Some(ins(extras)),
      "...",
    ),
    desugarer: desugarer_factory(extras),
  )
}
