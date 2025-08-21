import infrastructure.{type Selector, type SLine, type SMode} as infra

fn line_selector(
  _line: SLine,
) -> SMode {
  infra.OGS
}

pub fn selector() -> Selector {
  line_selector(_)
  |> infra.line_selector_to_selector()
}
