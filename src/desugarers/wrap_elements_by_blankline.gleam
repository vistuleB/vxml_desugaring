import gleam/list
import infrastructure.{type DesugaringError}
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

pub fn wrap_elements_by_blankline_desugarer(
  vxml: VXML,
  extra: List(String),
) -> Result(VXML, DesugaringError) {
  infrastructure.depth_first_node_to_nodes_desugarer(
    vxml,
    wrap_elements_by_blankline_transform,
    extra,
  )
}
