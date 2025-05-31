import gleam/list
import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  vxml: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(_, tag, _, _) ->
      case list.contains(param, tag) {
        True -> Ok([])
        False -> Ok([vxml])
      }
    _ -> Ok([vxml])
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

type Param = List(String)

type InnerParam = Param

pub fn remove_tag_desugarer(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_tag_desugarer",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
