import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, T, V}

pub fn insert_indent_transform(
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
