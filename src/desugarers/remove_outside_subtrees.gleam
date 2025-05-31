import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) ->
      case list.any(ancestors, param) {
        True -> Ok([vxml])
        False -> Ok([])
      }
    V(_, _, _, children) -> {
      case
        !list.is_empty(children) || list.any(ancestors, param) || param(vxml)
      {
        True -> Ok([vxml])
        False -> Ok([])
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(vxml, a, s1, s2, s3) { transform(vxml, a, s1, s2, s3, param) }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  fn(VXML) -> Bool

type InnerParam = Param

pub fn remove_outside_subtrees(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_outside_subtrees",
      option.Some(param |> ins),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
