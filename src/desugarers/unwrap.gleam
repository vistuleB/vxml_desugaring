import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V}

const ins = string.inspect

fn param_transform(
  node: VXML,
  tags: List(String),
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case list.contains(tags, tag) {
        False -> Ok([node])
        True -> Ok(children)
      }
    _ -> Ok([node])
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(String)
// list of tags to be unwrapped

/// to 'unwrap' a tag means to repalce the
/// tag by its children (replace a V- VXML node by
/// its children in the tree); this function unwraps
/// tags based solely on their name, as given by a
/// list of names of tags to unwrap
pub fn unwrap(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap", Some(ins(extra)), "to 'unwrap' a tag means to repalce the
tag by its children (replace a V- VXML node by
its children in the tree); this function unwraps
tags based solely on their name, as given by a
list of names of tags to unwrap"),
    desugarer: desugarer_factory(extra),
  )
}
