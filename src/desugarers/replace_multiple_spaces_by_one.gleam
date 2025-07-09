import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import vxml.{type VXML, T}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(blame, lines) -> {
      case lines {
        [] -> Ok(vxml)
        [first, ..] -> {
          case first.content |> string.starts_with(" ") {
            True -> {
              let new_line = " " <> first.content |> string.trim_start()
              Ok(
                T(blame, [
                  vxml.BlamedContent(first.blame, new_line),
                  ..list.drop(lines, 1)
                ]),
              )
            }
            False -> Ok(vxml)
          }
        }
      }
    }
    _ -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

const name = "replace_multiple_spaces_by_one"
const constructor = replace_multiple_spaces_by_one

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// replaces multiple consecutive spaces with a single space
pub fn replace_multiple_spaces_by_one(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// replaces multiple consecutive spaces with a single space
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
