import infrastructure.{type Selector, type PigeonLine} as infra
import gleam/string

pub fn pigeon_selector(
  pigeon: PigeonLine,
  s: String,
) -> Bool {
  case pigeon {
    infra.PigeonL(_, _, content) -> string.contains(content, s)
    _ -> False
  }
}

pub fn text(
  s: String,
) -> Selector {
  pigeon_selector(_, s)
  |> infra.pigeon_selector_to_selector()
}
