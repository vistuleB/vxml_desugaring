import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(_, tag, _, _) ->
      case list.contains(inner, tag) {
        True -> Ok([])
        False -> Ok([vxml])
      }
    _ -> Ok([vxml])
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

/// removes tags entirely (tag and children)
pub fn remove_tag_desugarer(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_tag_desugarer",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// removes tags entirely (tag and children)
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}