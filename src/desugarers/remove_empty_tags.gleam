import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, T, V}

fn is_empty(child: VXML) {
  case child {
    T(_, lines) -> list.all(lines, fn(x) { string.is_empty(x.content) })
    _ -> False
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) -> {
      case list.contains(inner, tag), list.all(children, is_empty) {
        True, True -> Ok([])
        _, _ -> Ok([node])
      }
    }
    _ -> Ok([node])
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

type InnerParam = List(String)

pub const desugarer_name = "remove_empty_tags"
pub const desugarer_pipe = remove_empty_tags

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// removes empty elements that contain only empty text nodes
pub fn remove_empty_tags(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.None,
    "
/// removes empty elements that contain only empty text nodes
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