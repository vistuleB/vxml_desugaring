import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeFancyTransform, type Pipe,
  DesugarerDescription, fancy_depth_first_node_to_node_desugarer,
}
import vxml_parser.{type VXML, T, V}

pub fn insert_indent_v1_transform(
  node: VXML,
  _: List(VXML),
  previous_unmapped_siblings: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: Nil,
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

fn transform_factory() -> NodeToNodeFancyTransform {
  fn(node, n, previous_unmapped_siblings, p, f) {
    insert_indent_v1_transform(node, n, previous_unmapped_siblings, p, f, Nil)
  }
}

fn desugarer_factory() -> Desugarer {
  fn(vxml) {
    fancy_depth_first_node_to_node_desugarer(vxml, transform_factory())
  }
}

pub fn insert_indent_v1_desugarer() -> Pipe {
  #(
    DesugarerDescription("insert_indent_v1_desugarer", option.None, "..."),
    desugarer_factory(),
  )
}
