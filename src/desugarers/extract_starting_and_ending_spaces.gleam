import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, _) -> {
      case list.contains(inner, tag) {
        True -> {
          let #(before, vxml) = vxml |> infra.v_extract_starting_spaces
          let #(after, vxml) = vxml |> infra.v_extract_ending_spaces
          Ok(option.values([before, option.Some(vxml), after]))
        }
        False -> Ok([vxml])
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)
type InnerParam = Param

pub const desugarer_name = "extract_starting_and_ending_spaces"
pub const desugarer_pipe = extract_starting_and_ending_spaces
//------------------------------------------------53
/// extracts starting and ending spaces from 
/// specified tags into separate text nodes
pub fn extract_starting_and_ending_spaces(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.Some(ins(param)),
    "
/// extracts starting and ending spaces from
/// specified tags into separate text nodes
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
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}