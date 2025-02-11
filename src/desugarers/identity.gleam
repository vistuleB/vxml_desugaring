import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML}

fn param_transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  Ok(vxml)
}

fn transform_factory(
) -> NodeToNodeTransform {
  param_transform
}

fn desugarer_factory(
) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn identity() -> Pipe {
  #(
    DesugarerDescription(
      "identity",
      option.None,
      "...",
    ),
    desugarer_factory(),
  )
}
