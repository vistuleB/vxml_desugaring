import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  let #(string_pairs, forbidden_parents) = inner
  infra.find_replace_in_node_transform_version(_, string_pairs)
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(List(#(String, String)), List(String))
//  ↖                        ↖
//  from/to pairs            keep_out_of

type InnerParam = Param

/// find and replace strings with other strings
pub fn find_replace(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "find_replace",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// find and replace strings with other strings
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}