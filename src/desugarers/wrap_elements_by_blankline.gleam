import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodesTransform, type Pipe,
  DesugarerDescription,
} as infra
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

type Extra =
  List(String)

fn transform_factory(extra: Extra) -> NodeToNodesTransform {
  wrap_elements_by_blankline_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

pub fn wrap_elements_by_blankline(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "wrap_elements_by_blankline",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra),
  )
}
