import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn nodemap(
  node: VXML,
  ancestors: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case node {
    V(_, tag, _, children) if tag == inner.0 -> case list.any(inner.1, fn(b) {list.any(ancestors, fn(a) { infra.tag_equals(a, b)})}) {
      True -> children
      False -> [node]
    }
    _ -> [node]
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNoErrorNodeMap {
  fn(
    vxml: VXML,
    ancestors: List(VXML),
    _: List(VXML),
    _: List(VXML),
    _: List(VXML),
  ) {
    nodemap(vxml, ancestors, inner)
  }
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.fancy_one_to_many_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String,        List(String))
//             ↖              ↖
//             tag to         list of ancestor names
//             be unwrapped   that should cause tag to unwrap
type InnerParam = Param

const name = "unwrap_if_descendant_of_no_list"
const constructor = unwrap_if_descendant_of_no_list

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// unwraps a given tag when it is the descendant of
/// one of a stipulated list of tags
pub fn unwrap_if_descendant_of_no_list(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// unwraps a given tag when it is the descendant of
/// one of a stipulated list of tags
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