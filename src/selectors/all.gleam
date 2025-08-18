import infrastructure.{type Selector, type PigeonLine} as infra

pub fn pigeon_selector(
  _pigeon: PigeonLine
) -> Bool {
  True
}

pub fn all() -> Selector {
  pigeon_selector(_)
  |> infra.pigeon_selector_to_selector()
}
