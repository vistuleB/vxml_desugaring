import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(_, tag, _, _) -> {
      case list.find(inner, fn(pair) { pair |> pair.first == tag }) {
        Error(Nil) -> Ok(vxml)
        Ok(#(_, #(start_text, end_text))) -> {
          vxml
          |> infra.v_start_insert_text(start_text)
          |> infra.v_end_insert_text(end_text)
          |> Ok
        }
      }
    }
    T(_, _) -> Ok(vxml)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> infra.triples_to_pairs
  |> Ok
}

type Param =
  List(#(String, String, String))
//       ↖      ↖       ↖
//       tag    start   end
//              text    text

type InnerParam =
  List(#(String, #(String, String)))

const name = "insert_bookend_text"
const constructor = insert_bookend_text

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// inserts text at the beginning and end of
/// specified tags
pub fn insert_bookend_text(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// inserts text at the beginning and end of
/// specified tags
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}