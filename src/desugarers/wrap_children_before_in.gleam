import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, V}

fn children_before(children: List(VXML), before_tag: String, acc: List(VXML)) -> #(List(VXML), List(VXML)) {
  case children {
    [] -> #([], [])
    [first, ..rest] -> {
      case first {
        V(_, tag, _, _) if tag == before_tag -> #(acc, children)
        _ -> {
          let #(acc, rest) = children_before(rest, before_tag, acc)
          #([first, ..acc], rest)
        }
      }
    }
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, stop_tag, wrapper_tag) = inner
  case node {
    V(b, tag, att, children) if tag == parent_tag -> {
        let #(before, after) = children_before(children, stop_tag, [])
        let children = [
          V(b, wrapper_tag, [], before),
          ..after,
        ]
        Ok(V(b, tag, att, children))
    }
    _ -> Ok(node)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)
//            ↖       ↖       ↖
//            parent  stop    wrapper
//            tag     tag     tag

type InnerParam = Param

pub const desugarer_name = "wrap_children_before_in"
pub const desugarer_pipe = wrap_children_before_in

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Wraps children of a node that appear 
/// before a certain child
pub fn wrap_children_before_in(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.Some(ins(param)),
    "
/// Wraps children of a node that appear 
/// before a certain child
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