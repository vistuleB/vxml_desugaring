import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> List(VXML) {
  case node {
    V(_, tag, _, children) -> case list.contains(inner.0, tag) && !list.any(children, inner.1) {
      True -> children
      False -> [node]
    }
    _ -> [node]
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_many_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(String), fn(VXML) -> Bool)
//             ↖             ↖
//             tags to       condition
//             unwrap
type InnerParam = Param

pub const name = "unwrap_if_no_child_meets_condition__batch"

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// for a specified list of tag strings, unwraps
/// nodes with tags from the list if the node does
/// not have any child meeting the boolean condition
pub fn constructor(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// for a specified list of tag strings, unwraps
/// nodes with tags from the list if the node does
/// not have any child meeting the boolean condition
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