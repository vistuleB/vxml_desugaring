import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T}

fn nodemap(
  vxml: VXML,
) -> VXML {
  case vxml {
    T(blame, lines) -> {
      case lines {
        [] -> vxml
        [first, ..] -> {
          case first.content |> string.starts_with(" ") {
            True -> {
              let new_line = " " <> first.content |> string.trim_start()
              T(blame, [
                vxml.BlamedContent(first.blame, new_line),
                ..list.drop(lines, 1)
              ])
            }
            False -> vxml
          }
        }
      }
    }
    _ -> vxml
  }
}

fn nodemap_factory(_: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "replace_multiple_spaces_by_one"
const constructor = replace_multiple_spaces_by_one

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// replaces multiple consecutive spaces with a single space
pub fn replace_multiple_spaces_by_one() -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// replaces multiple consecutive spaces with a single space
    ",
    case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_nil_param(name, assertive_tests_data(), constructor)
}
