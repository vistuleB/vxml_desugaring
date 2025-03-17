import gleam/option
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, BlamedAttribute, T, V}

pub fn insert_indent_transform(
  node: VXML,
  ancestors: List(VXML),
  previous_unmapped_siblings: List(VXML),
  _: List(VXML),
  _: List(VXML),
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, "VerticalChunk", attrs, children) -> {
      case previous_unmapped_siblings {
        [V(_, "VerticalChunk", _, _), ..] -> {
          case infra.contains_one_of_tags(ancestors, ["CentralDisplay", "CentralDisplayItalic"]) {
            True -> Ok(node)
            False -> Ok(V(
              blame,
              "VerticalChunk",
              [BlamedAttribute(blame, "indent", "true"), ..attrs],
              children,
            ))
          }
        }
        _ -> Ok(node)
      }
    }
    V(_, _, _, _) -> Ok(node)
  }
}

fn transform_factory() -> infra.NodeToNodeFancyTransform {
  insert_indent_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory())
}

pub fn insert_indent() -> Pipe {
  Pipe(
    description: DesugarerDescription("insert_indent", option.None, "..."),
    desugarer: desugarer_factory(),
  )
}
