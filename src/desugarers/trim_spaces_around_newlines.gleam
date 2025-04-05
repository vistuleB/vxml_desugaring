import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) ->
      vxml
      |> infra.trim_ending_spaces_except_last_line
      |> infra.trim_starting_spaces_except_first_line
      |> Ok
    _ -> Ok(vxml)
  }
}

fn transform_factory() -> infra.NodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn trim_spaces_around_newlines() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "trim_spaces_around_newlines",
      None,
      "...",
    ),
    desugarer: desugarer_factory(),
  )
}
