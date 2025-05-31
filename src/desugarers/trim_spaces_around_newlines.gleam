import gleam/option.{None}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) ->
      vxml
      |> infra.trim_ending_spaces_except_last_line
      |> infra.trim_starting_spaces_except_first_line
      |> Ok
    _ -> Ok(vxml)
  }
}

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub fn trim_spaces_around_newlines() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "trim_spaces_around_newlines",
      None,
      "...",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
