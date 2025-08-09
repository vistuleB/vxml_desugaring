import infrastructure.{type Selector} as infra
import gleam/list
import gleam/string

pub fn text(
  s: String,
) -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_pigeon_lines
    |> list.map(fn(pigeon) {
      case pigeon {
        infra.PigeonL(_, _, content) -> case string.contains(content, s) {
          True -> infra.OG(pigeon)
          False -> infra.NotSelected(pigeon)
        }
        _ -> infra.NotSelected(pigeon)
      }
    })
  }
}
