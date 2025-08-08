import infrastructure.{type Selector} as infra
import selectors/key_val.{key_val}

pub fn testtest_5_12() -> Selector {
  key_val("test", "test")
  |> infra.extend_selector_down(12)
  |> infra.extend_selector_up(5)
}
