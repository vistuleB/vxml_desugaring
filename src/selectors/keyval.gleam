import infrastructure.{type Selector, type PigeonLine} as infra

pub fn pigeon_selector(
  pigeon: PigeonLine,
  key: String,
  val: String,
) -> Bool {
  case pigeon {
    infra.PigeonA(_, _, k, v) if k == key && v == val -> True
    _ -> False
  }
}

pub fn keyval(
  key: String,
  val: String,
) -> Selector {
  pigeon_selector(_, key, val)
  |> infra.pigeon_selector_to_selector()
}
