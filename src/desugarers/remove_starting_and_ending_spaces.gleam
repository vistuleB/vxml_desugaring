import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn transform(vxml: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, tag, _, _) -> {
      case list.contains(param, tag) {
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(String)

type InnerParam = Param

pub fn remove_starting_and_ending_spaces(param: Param) -> Pipe {
  Pipe(
    DesugarerDescription(
      "remove_starting_and_ending_spaces",
      option.Some(ins(param)),
      "...",
    ),
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
