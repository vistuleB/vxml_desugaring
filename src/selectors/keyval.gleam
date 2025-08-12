import infrastructure.{type Selector, type InternalSelector} as infra
import gleam/list

pub fn keyval_internal_selector(
  key: String,
  val: String,
) -> InternalSelector {
  list.map(
    _,
    fn(line: infra.SelectedPigeonLine) {
      let pigeon = line.payload
      case pigeon {
        infra.PigeonA(_, _, k, v) if k == key && v == val -> infra.OG(pigeon)
        _ -> infra.NotSelected(pigeon)
      }
    }
  )
}

pub fn keyval(
  key: String,
  val: String,
) -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_unselected_lines
    |> keyval_internal_selector(key, val)
  }
}
