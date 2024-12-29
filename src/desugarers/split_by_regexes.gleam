import gleam/option.{Some}
import gleam/regexp.{type Regexp}
import gleam/string
import infrastructure.{
  type Desugarer, type NodeToNodesFancyTransform, type Pipe,
  DesugarerDescription, replace_regexes_by_tags_param_transform,
} as infra

const ins = string.inspect

type Extras =
  #(List(#(Regexp, String)), List(String))

fn transform_factory(extras: Extras) -> NodeToNodesFancyTransform {
  let #(regexes_and_tags, forbidden_parents) = extras
  replace_regexes_by_tags_param_transform(_, regexes_and_tags)
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(extras: Extras) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extras))
}

pub fn split_by_regexes(extras: Extras) -> Pipe {
  #(
    DesugarerDescription("split_by_regexes", Some(ins(extras)), "..."),
    desugarer_factory(extras),
  )
}
