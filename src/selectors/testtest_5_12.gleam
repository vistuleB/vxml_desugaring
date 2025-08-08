import vxml.{type VXML}
import selectors/within_pm_lines_of_key_val.{within_pm_lines_of_key_val}
import infrastructure.{type SelectedPigeonLine}

pub fn testtest_5_12(
  vxml: VXML,
) -> List(SelectedPigeonLine) {
  within_pm_lines_of_key_val(vxml, "test", "test", 5, 12)
}
