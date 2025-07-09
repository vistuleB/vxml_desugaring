import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
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

fn nodemap(
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

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)
//            ↖       ↖       ↖
//            parent  stop    wrapper
//            tag     tag     tag

type InnerParam = Param

const name = "wrap_children_before_in"
const constructor = wrap_children_before_in

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Wraps children of a node that appear 
/// before a certain child
pub fn wrap_children_before_in(param: Param) -> Desugarer {
  Desugarer(
    name,
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
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}