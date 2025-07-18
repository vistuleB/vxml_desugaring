import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) -> {
      let #(tags, condition) = inner
      case list.contains(tags, tag), list.any(children, condition) {
        True, False -> Ok(children)
        _, _ -> Ok([node])
      }
    }
    _ -> Ok([node])
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(String), fn(VXML) -> Bool)
type InnerParam = Param

const name = "unwrap_tags_when_no_child_meets_condition"
const constructor =  unwrap_tags_when_no_child_meets_condition

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// for a specified list of tag strings, unwraps
/// nodes with tags from the list if the node does
/// not have any child meeting the boolean condition
pub fn unwrap_tags_when_no_child_meets_condition(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
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