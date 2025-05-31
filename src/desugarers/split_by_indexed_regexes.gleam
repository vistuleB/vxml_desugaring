import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import indexed_regex_splitting as rs

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  let #(regexes_and_tags, forbidden_parents) = param
  rs.split_by_regexes_with_indexed_group_node_to_nodes_transform(
    _,
    regexes_and_tags,
  )
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(#(rs.RegexWithIndexedGroup, String)), List(String))
type InnerParam = Param

pub fn split_by_indexed_regexes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "split_by_indexed_regexes",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
