import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) ->
      vxml
      |> infra.trim_ending_spaces_except_last_line
      |> infra.trim_starting_spaces_except_first_line
      |> Ok
    _ -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// trims spaces around newlines in text nodes
pub fn trim_spaces_around_newlines() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "trim_spaces_around_newlines",
      stringified_param: option.None,
      general_description: "
/// trims spaces around newlines in text nodes
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
