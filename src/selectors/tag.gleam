import infrastructure.{type Selector, type InternalSelector} as infra
import gleam/list

pub fn tag_internal_selector(
  tag: String,
) -> InternalSelector {
  list.map(
    _,
    fn(line: infra.SelectedPigeonLine) {
      let pigeon = line.payload
      case pigeon {
        infra.PigeonV(_, _, tag_name) if tag_name == tag -> infra.OG(pigeon)
        _ -> infra.NotSelected(pigeon)
      }
    }
  )
}

pub fn tag(
  tag: String,
) -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_unselected_lines
    |> tag_internal_selector(tag)
  }
}
