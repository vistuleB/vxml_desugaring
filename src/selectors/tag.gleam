import infrastructure.{type Selector, type PigeonSelector} as infra
import gleam/list

pub fn tag_pigeon_version(
  tag: String,
) -> PigeonSelector {
  list.map(
    _,
    fn(pigeon) {
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
    |> infra.vxml_to_pigeon_lines
    |> tag_pigeon_version(tag)
  }
}
