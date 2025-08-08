import infrastructure.{type SelectedPigeonLine} as infra
import vxml.{type VXML}
import gleam/list

pub fn within_pm_lines_of_key_val(
  root: VXML,
  key: String,
  val: String,
  lines_below: Int,
  lines_above: Int,
) -> List(SelectedPigeonLine) {
  root
  |> infra.vxml_to_pigeon_lines
  |> list.map(fn(pigeon) {
    case pigeon {
      infra.PigeonA(_, _, k, v) if k == key && v == val -> infra.OG(pigeon)
      _ -> infra.NotSelected(pigeon)
    }
  })
  |> infra.extend_selection_down(lines_below)
  |> infra.extend_selection_up(lines_above)
}
