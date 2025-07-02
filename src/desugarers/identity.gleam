import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  Ok(vxml)
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

pub const desugarer_name = "identity"
pub const desugarer_pipe =  identity

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// idempotent desugarer that leaves the VXML 
/// unchanged and that never generates an error
pub fn identity() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.None,
      general_description: "
/// idempotent desugarer that leaves the VXML 
/// unchanged and that never generates an error
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(desugarer_name, assertive_tests_data(), desugarer_pipe)
}