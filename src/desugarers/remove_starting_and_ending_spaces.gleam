import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, tag, _, _) -> {
      case list.contains(inner, tag) {
        True -> {
          let #(_, vxml) = vxml |> infra.v_extract_starting_spaces
          let #(_, vxml) = vxml |> infra.v_extract_ending_spaces
          Ok(vxml)
        }
        False -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)

type InnerParam = Param

/// removes starting and ending spaces from specified tags
pub fn remove_starting_and_ending_spaces(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_starting_and_ending_spaces",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// removes starting and ending spaces from specified tags
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}