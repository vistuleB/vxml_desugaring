import gleam/bool.{negate}
import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodesTransform, type Pipe,
  DesugarerDescription, DesugaringError,
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

fn transform_factory() -> NodeToNodesTransform {
  remove_empty_lines_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory())
}

pub fn remove_empty_lines() -> Pipe {
  #(
    DesugarerDescription("remove_empty_lines", option.None, "..."),
    desugarer_factory(),
  )
}
