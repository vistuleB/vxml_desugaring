import gleam/list
import gleam/option
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe } as infra
import vxml.{type VXML, T, V}

fn transform(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok([node])
    T(blame, lines) -> {
      case list.length(lines) == 1 && infra.first_line(lines).content == "" {
        True -> Ok([])
        False -> Ok([T(blame, lines)])
      }
    }
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodesTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// removes text nodes containing a single line
/// consisting of an empty string
pub fn remove_text_nodes_with_singleton_empty_line() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "remove_text_nodes_with_singleton_empty_line",
      stringified_param: option.None,
      general_description: "
/// removes text nodes containing a single line
/// consisting of an empty string
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
