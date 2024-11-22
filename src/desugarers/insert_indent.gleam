import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, BlamedAttribute, T, V}

pub fn insert_indent_transform(
  node: VXML,
  _: List(VXML),
  previous_unmapped_siblings: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: Nil,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, "VerticalChunk", attrs, children) -> {
      case previous_unmapped_siblings {
        [V(_, "VerticalChunk", _, _), ..] ->
          Ok(V(
            blame,
            "VerticalChunk",
            [BlamedAttribute(blame, "indent", "true"), ..attrs],
            children,
          ))
        _ -> Ok(node)
      }
    }
    V(_, _, _, _) -> Ok(node)
  }
}

pub fn insert_indent_desugarer(vxml: VXML) {
  infrastructure.fancy_depth_first_node_to_node_desugarer(
    vxml,
    insert_indent_transform,
    Nil,
  )
}
