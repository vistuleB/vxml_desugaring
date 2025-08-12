import infrastructure.{type Selector, type InternalSelector} as infra
import gleam/list
import gleam/string

pub fn text_internal_selector(
  s: String,
) -> InternalSelector {
  list.map(
    _,
    fn(line: infra.SelectedPigeonLine) {
      let pigeon = line.payload
      case pigeon {
        infra.PigeonL(_, _, content) -> case string.contains(content, s) {
          True -> infra.OG(pigeon)
          False -> infra.NotSelected(pigeon)
        }
        _ -> infra.NotSelected(pigeon)
      }
    }
  )
}

pub fn text(
  s: String,
) -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_unselected_lines
    |> text_internal_selector(s)
  }
}
