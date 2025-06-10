import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import indexed_regex_splitting as rs

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  let #(regexes_and_tags, forbidden_parents) = inner
  rs.split_by_regexes_with_indexed_group_node_to_nodes_transform(
    _,
    regexes_and_tags,
  )
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(#(rs.RegexWithIndexedGroup, String)), List(String))
//              ↖                                         ↖
//              regexes_and_tags                          forbidden_parents

type InnerParam = Param

/// splits text nodes by indexed regexes
pub fn split_by_indexed_regexes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "split_by_indexed_regexes",
      stringified_param: option.Some(ins(param)),
      general_description: "/// splits text nodes by indexed regexes",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}