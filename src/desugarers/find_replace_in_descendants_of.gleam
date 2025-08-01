import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
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
) -> Result(VXML, infra.DesugaringError) {
  case vxml {
    V(_, _, _, _) -> Ok(vxml)
    T(_, _) -> {
      list.fold(inner, vxml, fn(v, tuple) -> VXML {
        let #(ancestor, list_pairs) = tuple
        case list.any(ancestors, fn(a) { infra.get_tag(a) == ancestor }) {
          False -> v
          True -> infra.find_replace_in_t(vxml, list_pairs)
        }
      })
      |> Ok
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToOneNodeMap {
  fn(vxml, ancestors, s1, s2, s3) {
    nodemap(vxml, ancestors, s1, s2, s3, inner)
  }
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,   List(#(String, String))))
//       ↖         ↖
//       ancestor  from/to pairs

type InnerParam = Param

const name = "find_replace_in_descendants_of"
const constructor = find_replace_in_descendants_of

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// find and replace strings in text nodes that are
/// descendants of specified ancestor tags
pub fn find_replace_in_descendants_of(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// find and replace strings in text nodes that are
/// descendants of specified ancestor tags
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
  [
    infra.AssertiveTestData(
      param: [#("ancestor", [#("_FROM_", "_TO_")])],
      source:   "
                <> root
                  <> B
                    <>
                      \"hello _FROM_\"
                      \"_FROM__FROM_\"
                  <> ancestor
                    <> B
                      <>
                        \"hello _FROM_\"
                        \"_FROM__FROM_\"
                ",
      expected: "
                <> root
                  <> B
                    <>
                      \"hello _FROM_\"
                      \"_FROM__FROM_\"
                  <> ancestor
                    <> B
                      <>
                        \"hello _TO_\"
                        \"_TO__TO_\"
                ",
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}