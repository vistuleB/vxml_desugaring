import infrastructure.{type Selector, type InternalSelector} as infra

pub fn pigeon_selector(
  _pigeon: infra.PigeonLine
) -> Bool {
  True
}

pub fn all_internal_selector() -> InternalSelector {
  pigeon_selector(_)
  |> infra.pigeon_selector_to_internal_selector()
}

pub fn all() -> Selector {
  pigeon_selector(_)
  |> infra.pigeon_selector_to_selector()
}
