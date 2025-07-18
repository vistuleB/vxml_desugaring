import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T}

fn nodemap(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) ->
      vxml
      |> infra.trim_ending_spaces_except_last_line
      |> infra.trim_starting_spaces_except_first_line
      |> Ok
    _ -> Ok(vxml)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToOneNodeMap {
  nodemap
  |> n2t.prevent_node_to_node_transform_inside(inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String) // forbidden tags
type InnerParam = Param

const name = "trim_spaces_around_newlines"
const constructor = trim_spaces_around_newlines

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// trims spaces around newlines in text nodes
/// outside of subtrees rooted at tags given by the
/// param argument
pub fn trim_spaces_around_newlines(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// trims spaces around newlines in text nodes
/// outside of subtrees rooted at tags given by the
/// param argument
    ",
    case param_to_inner_param(param) {
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
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
