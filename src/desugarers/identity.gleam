import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  Ok(vxml)
}

fn transform_factory() -> infra.NodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn identity() -> Pipe {
  Pipe(
    description: DesugarerDescription("identity", option.None, "..."),
    desugarer: desugarer_factory(),
  )
}
