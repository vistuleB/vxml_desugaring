import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, V}

pub fn remove_tag_transform(
  vxml: VXML,
  extra: List(String),
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(_, tag, _, _) ->
      case list.contains(extra, tag) {
        True -> Ok([])
        False -> Ok([vxml])
      }
    _ -> Ok([vxml])
  }
}
