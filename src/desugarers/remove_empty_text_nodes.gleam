import gleam/list
import gleam/option
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type BlamedContent, type VXML, BlamedContent, T, V}

fn content_is_nonempty(blamed_content: BlamedContent) {
  case blamed_content {
    BlamedContent(_, "") -> False
    _ -> True
  }
}

fn remove_empty_lines_transform(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok([node])
    T(blame, lines) -> {
      let nonempty_lines = list.filter(lines, content_is_nonempty)
      case list.is_empty(nonempty_lines) {
        True -> Ok([])
        False -> Ok([T(blame, lines)])
      }
    }
  }
}

fn transform_factory() -> infra.NodeToNodesTransform {
  remove_empty_lines_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory())
}

pub fn remove_empty_text_nodes() -> Pipe {
  Pipe(
    description: DesugarerDescription("remove_empty_text_nodes", option.None, "..."),
    desugarer: desugarer_factory(),
  )
}
