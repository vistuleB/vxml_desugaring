import infrastructure.{type Selector, type InternalSelector} as infra
import gleam/list

pub fn all_internal_selector() -> InternalSelector {
  list.map(_, fn(x: infra.SelectedPigeonLine) {infra.Byproduct(x.payload)})
}

pub fn all() -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_unselected_lines
    |> all_internal_selector()
  }
}
