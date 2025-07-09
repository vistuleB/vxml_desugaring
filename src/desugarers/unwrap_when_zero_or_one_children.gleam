import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case list.contains(inner, tag) && list.length(children) <= 1 {
        False -> Ok([node])
        True -> Ok(children)
      }
    _ -> Ok([node])
  }
}

fn transform_factory(inner: InnerParam) -> n2t.NodeToNodesTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(String)

type InnerParam =
  Param

const name = "unwrap_when_zero_or_one_children"
const constructor = unwrap_when_zero_or_one_children

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// unwraps based on tag name if node
/// has zero or one children
pub fn unwrap_when_zero_or_one_children(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// unwraps based on tag name if node
/// has zero or one children
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    },
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
