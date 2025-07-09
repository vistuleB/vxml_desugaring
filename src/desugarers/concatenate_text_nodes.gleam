import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import vxml.{type VXML, V}

fn transform(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    V(_, _, _, children) -> {
      Ok(V(..node, children: infra.plain_concatenation_in_list(children)))
    }
    _ -> Ok(node)
  }
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

const name = "concatenate_text_nodes"
const constructor = concatenate_text_nodes

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// concatenates adjacent text nodes into single
/// text nodes
pub fn concatenate_text_nodes() -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// concatenates adjacent text nodes into single
/// text nodes
    ",
    case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_nil_param(name, assertive_tests_data(), constructor)
}
