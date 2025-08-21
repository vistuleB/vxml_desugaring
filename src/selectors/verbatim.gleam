import infrastructure.{type Selector, type SLine, type SMode} as infra
import gleam/string

fn line_selector(
  line: SLine,
  s: String,
) -> SMode {
  case string.contains(line.content, s) {
    True -> infra.OGS
    _ -> infra.NotS
  }
}

pub fn selector(
  s: String,
) -> Selector {
  line_selector(_, s)
  |> infra.line_selector_to_selector()
}
