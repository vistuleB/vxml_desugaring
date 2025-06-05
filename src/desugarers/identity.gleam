import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  Ok(vxml)
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

/// idempotent desugarer that leaves the
/// VXML unchanged
pub fn identity() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "identity",
      stringified_param: option.None,
      general_description: "
/// idempotent desugarer that leaves the
/// VXML unchanged
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
