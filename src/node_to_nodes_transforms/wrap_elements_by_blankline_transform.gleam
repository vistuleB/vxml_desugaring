import gleam/list
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML, T, V}

pub type WrapByBlankLineExtraArgs {
  WrapByBlankLineExtraArgs(tags: List(String))
}

pub fn wrap_elements_by_blankline_transform(
  node: VXML,
  _: List(VXML),
  extra: WrapByBlankLineExtraArgs,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(blame, tag, _, _) -> {
      case list.contains(extra.tags, tag) {
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
