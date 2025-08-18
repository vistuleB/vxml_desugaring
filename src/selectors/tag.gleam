import infrastructure.{type Selector, type PigeonLine} as infra

pub fn pigeon_selector(
  pigeon: PigeonLine,
  tag: String,
) -> Bool {
  case pigeon {
    infra.PigeonV(_, _, tag_name) if tag_name == tag -> True
    _ -> False
  }
}

pub fn tag(
  tag: String,
) -> Selector {
  pigeon_selector(_, tag)
  |> infra.pigeon_selector_to_selector()
}
