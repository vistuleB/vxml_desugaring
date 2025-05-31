import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn transform(
  vxml: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, _) -> {
      case list.contains(param, tag) {
        True -> {
          let #(before, vxml) = vxml |> infra.v_extract_starting_spaces
          let #(after, vxml) = vxml |> infra.v_extract_ending_spaces
          Ok(option.values([before, Some(vxml), after]))
        }
        False -> Ok([vxml])
      }
    }
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

type InnerParam = Param

pub fn extract_starting_and_ending_spaces(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "extract_starting_and_ending_spaces",
      option.Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
