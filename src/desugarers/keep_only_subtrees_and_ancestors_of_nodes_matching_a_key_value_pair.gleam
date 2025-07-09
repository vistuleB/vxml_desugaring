import desugarers/remove_outside_subtrees.{remove_outside_subtrees}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Desugarer, Desugarer} as infra
import vxml.{type VXML, V}

fn matches_a_key_value_pair(vxml: VXML, inner: InnerParam) -> Bool {
  let assert V(_, _, attrs, _) = vxml
  list.any(inner, fn(selector) {
    let #(key, value) = selector
    list.any(attrs, fn(attr) { attr.key == key && attr.value == value })
  })
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))
//       ↖       ↖
//       key     value

type InnerParam = Param

const name = "keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair"
const constructor = keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// filters by identifying nodes whose attributes
/// match at least one of the given #(key, value)
/// pairs. (OR not AND); keeps only nodes that are
/// descendants of such nodes, or ancestors of such 
/// nodes
pub fn keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair(
  param: Param,
) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// filters by identifying nodes whose attributes
/// match at least one of the given #(key, value)
/// pairs. (OR not AND); keeps only nodes that are
/// descendants of such nodes, or ancestors of such 
/// nodes
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> case inner {
        [] -> fn(vxml) { Ok(vxml) }
        _ -> remove_outside_subtrees(matches_a_key_value_pair(_, inner)).transform
      }
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