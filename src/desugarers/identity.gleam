import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import vxml.{type VXML}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  Ok(vxml)
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

const name = "identity"
const constructor =  identity

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// idempotent desugarer that leaves the VXML 
/// unchanged and that never generates an error
pub fn identity(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// idempotent desugarer that leaves the VXML 
/// unchanged and that never generates an error
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
fn assertive_tests_data() -> List(infra.AssertiveTestData(Nil)) {
  [
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}