import infrastructure.{type Selector, type InternalSelector} as infra

pub fn pigeon_selector(
  pigeon: infra.PigeonLine,
  tag: String,
) -> Bool {
  case pigeon {
    infra.PigeonV(_, _, tag_name) if tag_name == tag -> True
    _ -> False
  }
}

pub fn tag_internal_selector(
  tag: String,
) -> InternalSelector {
  pigeon_selector(_, tag)
  |> infra.pigeon_selector_to_internal_selector()
}

pub fn tag(
  tag: String,
) -> Selector {
  pigeon_selector(_, tag)
  |> infra.pigeon_selector_to_selector()
}
