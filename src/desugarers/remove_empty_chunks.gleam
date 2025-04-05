import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn is_empty(child: VXML) {
  case child {
    T(_, lines) -> list.all(lines, fn(x) { string.is_empty(x.content) })
    _ -> False
  }
}

pub fn remove_empty_chunks_transform(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(_, tag, _, children) -> {
      case tag == "VerticalChunk" {
        True -> {
          case list.all(children, is_empty) {
            True -> Ok([])
            False -> Ok([node])
          }
        }

        False -> Ok([node])
      }
    }
  }
}

fn transform_factory() -> infra.NodeToNodesTransform {
  remove_empty_chunks_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory())
}

pub fn remove_empty_chunks() -> Pipe {
  Pipe(
    description: DesugarerDescription("remove_empty_chunks", option.None, "..."),
    desugarer: desugarer_factory(),
  )
}
