import desugarers/remove_outside_subtrees.{remove_outside_subtrees}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Desugarer, Desugarer} as infra
import vxml.{type VXML, V}

fn matches_a_selector(vxml: VXML, inner: InnerParam) -> Bool {
  let assert V(b, _, attrs, _) = vxml
  list.any(inner, fn(selector) {
    let #(path, key, value) = selector
    {
      string.contains(b.filename, path)
      && {
        key == ""
        || list.any(attrs, fn(attr) {
          { attr.key == key && attr.value == value }
        })
      }
    }
  })
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String, String))
//       ↖      ↖       ↖
//       path   key     value

type InnerParam = Param

const name = "filter_nodes_by_attributes"
const constructor = filter_nodes_by_attributes

//------------------------------------------------53
/// filters by identifying nodes whose
/// blame.filename contain the extra.path as a 
/// substring and whose attributes match at least
/// one of the given #(key, value) pairs, with a
/// match counting as true if key == ""; keeps only
/// nodes that are descendants of such nodes, or
/// ancestors of such nodes
pub fn filter_nodes_by_attributes(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// filters by identifying nodes whose
/// blame.filename contain the extra.path as a 
/// substring and whose attributes match at least
/// one of the given #(key, value) pairs, with a
/// match counting as true if key == \"\"; keeps only
/// nodes that are descendants of such nodes, or
/// ancestors of such nodes
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> case inner {
        [] -> fn(vxml) { Ok(vxml) }
        _ -> remove_outside_subtrees(matches_a_selector(_, inner)).transform
      }
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}