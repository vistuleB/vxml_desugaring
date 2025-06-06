import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  node: VXML,
  _: List(VXML),
  previous_unmapped_siblings: List(VXML),
  _: List(VXML),
  _: List(VXML),
) -> Result(VXML, DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok(node)
    T(blame, _) -> {
      case previous_unmapped_siblings {
        [] -> Ok(node)
        [first, ..] ->
          case first {
            T(_, _) -> Ok(V(blame, "Indent", [], [node]))
            _ -> Ok(node)
          }
      }
    }
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeFancyTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// wraps text nodes that follow other text nodes with Indent tags
pub fn insert_indent_v1_desugarer() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "insert_indent_v1_desugarer",
      stringified_param: option.None,
      general_description: "
/// wraps text nodes that follow other text nodes with Indent tags
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
