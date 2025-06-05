import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case list.contains(inner, tag) {
        False -> Ok([node])
        True -> Ok(children)
      }
    _ -> Ok([node])
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)

type InnerParam = Param

/// to 'unwrap' a tag means to replace the
/// tag by its children (replace a V- VXML node by
/// its children in the tree); this function unwraps
/// tags based solely on their name, as given by a
/// list of names of tags to unwrap
pub fn unwrap(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "unwrap",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// to 'unwrap' a tag means to replace the
/// tag by its children (replace a V- VXML node by
/// its children in the tree); this function unwraps
/// tags based solely on their name, as given by a
/// list of names of tags to unwrap
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}