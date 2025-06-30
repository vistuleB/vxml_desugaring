import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    V(_, _, _, children) -> {
      Ok(V(..node, children: infra.plain_concatenation_in_list(children)))
    }
    _ -> Ok(node)
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

/// concatenates adjacent text nodes into single text nodes
pub fn concatenate_text_nodes() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "concatenate_text_nodes",
      stringified_param: option.None,
      general_description: "
/// concatenates adjacent text nodes into single text nodes
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
