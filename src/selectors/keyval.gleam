import infrastructure.{type Selector, type PigeonSelector} as infra
import gleam/list

pub fn keyval_pigeon_version(
  key: String,
  val: String,
) -> PigeonSelector {
  list.map(
    _,
    fn(pigeon) {
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
    |> infra.vxml_to_pigeon_lines
    |> keyval_pigeon_version(key, val)
  }
}
