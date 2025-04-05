import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

pub fn insert_indent_v1_transform(
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

fn transform_factory() -> infra.NodeToNodeFancyTransform {
  insert_indent_v1_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory())
}

pub fn insert_indent_v1_desugarer() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "insert_indent_v1_desugarer",
      option.None,
      "...",
    ),
    desugarer: desugarer_factory(),
  )
}
