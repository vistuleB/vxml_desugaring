import infrastructure.{type Selector} as infra
import gleam/list

pub fn key_val(
  key: String,
  val: String,
) -> Selector {
  fn (vxml) {
    vxml 
    |> infra.vxml_to_pigeon_lines
    |> list.map(fn(pigeon) {
      case pigeon {
        infra.PigeonA(_, _, k, v) if k == key && v == val -> infra.OG(pigeon)
        _ -> infra.NotSelected(pigeon)
      }
    })
  }
}
