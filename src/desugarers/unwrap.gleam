import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

const ins = string.inspect

fn transform(
  node: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case list.contains(param, tag) {
        False -> Ok([node])
        True -> Ok(children)
      }
    _ -> Ok([node])
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(String)
// list of tags to be unwrapped

type InnerParam = Param

/// to 'unwrap' a tag means to repalce the
/// tag by its children (replace a V- VXML node by
/// its children in the tree); this function unwraps
/// tags based solely on their name, as given by a
/// list of names of tags to unwrap
pub fn unwrap(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap", Some(ins(param)), "to 'unwrap' a tag means to repalce the
tag by its children (replace a V- VXML node by
its children in the tree); this function unwraps
tags based solely on their name, as given by a
list of names of tags to unwrap"),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
