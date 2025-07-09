import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, tag, _, _) -> {
      case list.contains(inner, tag) {
        True -> {
          let #(_, vxml) = vxml |> infra.v_extract_starting_spaces
          let #(_, vxml) = vxml |> infra.v_extract_ending_spaces
          Ok(vxml)
        }
        False -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)

type InnerParam = Param

const name = "remove_starting_and_ending_spaces"
const constructor = remove_starting_and_ending_spaces

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// removes starting and ending spaces from specified tags
pub fn remove_starting_and_ending_spaces(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// removes starting and ending spaces from specified tags
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