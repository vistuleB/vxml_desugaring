import infrastructure.{type Selector} as infra
import gleam/list

pub fn tag(
  tag: String,
) -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_pigeon_lines
    |> list.map(fn(pigeon) {
      case pigeon {
        infra.PigeonV(_, _, tag_name) if tag_name == tag -> infra.OG(pigeon)
        _ -> infra.NotSelected(pigeon)
      }
    })
  }
}
