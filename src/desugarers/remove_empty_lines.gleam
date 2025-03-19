import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
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
      let new_lines = list.filter(lines, content_is_nonempty)
      case list.is_empty(new_lines) {
        True -> Ok([])
        False -> Ok([T(blame, new_lines)])
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

/// for each text node, removes each line whose
/// content is the empty string & destroys 
/// text nodes that end up with 0 lines
pub fn remove_empty_lines() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_empty_lines",
      option.None,
      "for each text node, removes each line whose
content is the empty string & destroys 
text nodes that end up with 0 lines",
    ),
    desugarer: desugarer_factory(),
  )
}
