import infrastructure.{type Selector, type InternalSelector} as infra
import gleam/string

pub fn pigeon_selector(
  pigeon: infra.PigeonLine,
  s: String,
) -> Bool {
  case pigeon {
    infra.PigeonL(_, _, content) -> string.contains(content, s)
    _ -> False
  }
}

pub fn text_internal_selector(
  s: String,
) -> InternalSelector {
  pigeon_selector(_, s)
  |> infra.pigeon_selector_to_internal_selector()
}

pub fn text(
  s: String,
) -> Selector {
  pigeon_selector(_, s)
  |> infra.pigeon_selector_to_selector()
}
