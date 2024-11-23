import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodesTransform, type Pipe,
  DesugarerDescription, depth_first_node_to_nodes_desugarer,
}
import vxml_parser.{type VXML, T, V}

pub fn wrap_elements_by_blankline_transform(
  node: VXML,
  tags: List(String),
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(blame, tag, _, _) -> {
      case list.contains(tags, tag) {
        True -> {
          let blank_line =
            V(
              blame: blame,
              tag: "WriterlyBlankLine",
              attributes: [],
              children: [],
            )

          Ok([blank_line, node, blank_line])
        }
        False -> Ok([node])
      }
    }
  }
}

fn transform_factory(extra: List(String)) -> NodeToNodesTransform {
  fn(node) { wrap_elements_by_blankline_transform(node, extra) }
}

fn desugarer_factory(extra: List(String)) -> Desugarer {
  fn(vxml) {
    depth_first_node_to_nodes_desugarer(vxml, transform_factory(extra))
  }
}

pub fn wrap_elements_by_blankline_desugarer(extra: List(String)) -> Pipe {
  #(
    DesugarerDescription(
      "wrap_elements_by_blankline_desugarer",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra),
  )
}
