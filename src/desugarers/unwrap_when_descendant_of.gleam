import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn nodemap(
  node: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case infra.use_list_pair_as_dict(inner, tag) {
        Error(Nil) -> Ok([node])
        Ok(forbidden) -> {
          let ancestor_names = list.map(ancestors, infra.get_tag)
          case list.any(ancestor_names, list.contains(forbidden, _)) {
            True -> Ok(children)
            False -> Ok([node])
          }
        }
      }
    _ -> Ok([node])
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  fn(vxml: VXML, s1: List(VXML), s2: List(VXML), s3: List(VXML), s4: List(VXML)) {
    nodemap(vxml, s1, s2, s3, s4, inner)
  }
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(#(String, List(String)))
//              ↖       ↖
//              tag to  list of ancestor names
//              be      that will cause tag to unwrap
//              unwrapped

type InnerParam = Param

const name = "unwrap_when_descendant_of"
const constructor = unwrap_when_descendant_of

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// unwraps tags that are the descendant of
/// one of a stipulated list of tag names
pub fn unwrap_when_descendant_of(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// unwraps tags that are the descendant of
/// one of a stipulated list of tag names
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