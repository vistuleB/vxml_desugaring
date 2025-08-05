import vxml.{type VXML}
import selectors/within_x_lines_below_key_val.{within_x_lines_below_key_val}

pub fn within_x_lines_below_testtest(
  vxml: VXML,
  within: Int,
) -> List(VXML) {
  within_x_lines_below_key_val(vxml, "test", "test", within)
}
