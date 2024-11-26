import codepoints.{type DelimiterPattern}
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type NodeToNodesFancyTransform, type Pipe,
  DesugarerDescription, replace_delimiter_patterns_by_tags_param_transform,
} as infra

const ins = string.inspect

type Extras =
  #(List(#(DelimiterPattern, String)), List(String))

fn transform_factory(extras: Extras) -> NodeToNodesFancyTransform {
  let #(patterns_and_tags, forbidden_parents) = extras
  replace_delimiter_patterns_by_tags_param_transform(_, patterns_and_tags)
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(extras: Extras) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extras))
}

pub fn split_by_delimiter_pattern(extras: Extras) -> Pipe {
  #(
    DesugarerDescription(
      "split_by_delimiter_patterns",
      Some(ins(extras)),
      "...",
    ),
    desugarer_factory(extras),
  )
}
