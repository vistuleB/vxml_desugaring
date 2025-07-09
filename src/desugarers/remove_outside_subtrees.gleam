import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn nodemap(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) ->
      case list.any(ancestors, inner) {
        True -> Ok([vxml])
        False -> Ok([])
      }
    V(_, _, _, children) -> {
      case
        !list.is_empty(children) || list.any(ancestors, inner) || inner(vxml)
      {
        True -> Ok([vxml])
        False -> Ok([])
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  fn(vxml, a, s1, s2, s3) { nodemap(vxml, a, s1, s2, s3, inner) }
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = fn(VXML) -> Bool
type InnerParam = Param

const name = "remove_outside_subtrees"
const constructor = remove_outside_subtrees

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// removes nodes that are outside subtrees matching
/// the predicate function
pub fn remove_outside_subtrees(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// removes nodes that are outside subtrees matching
/// the predicate function
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
  [
    infra.AssertiveTestData(
      param: infra.is_v_and_tag_equals(_, "keep_this"),
      source:   "
                <> R
                  <>
                    \"hello world\"
                  <> blabla
                  <> keep_this
                    <>
                      \"hello world\"
                ",
      expected: "
                <> R
                  <> keep_this
                    <>
                      \"hello world\"
                ",
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}