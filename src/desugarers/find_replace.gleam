import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  let #(string_pairs, forbidden_parents) = param
  infra.find_replace_in_node_transform_version(_, string_pairs)
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(List(#(String, String)), List(String))

//         from    to        keep_out_of

type InnerParam = Param

pub fn find_replace(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("find_replace", Some(ins(param)), "..."),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
