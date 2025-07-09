import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import indexed_regex_splitting as rs

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  let #(regexes_and_tags, forbidden_parents) = inner
  rs.split_by_regexes_with_indexed_group_node_to_nodes_transform(
    _,
    regexes_and_tags,
  )
  |> n2t.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(#(rs.RegexWithIndexedGroup, String)), List(String))
//              ↖                                         ↖
//              regexes_and_tags                          forbidden_parents

type InnerParam = Param

const name = "split_by_indexed_regexes"
const constructor = split_by_indexed_regexes

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// splits text nodes by indexed regexes
pub fn split_by_indexed_regexes(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// splits text nodes by indexed regexes
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