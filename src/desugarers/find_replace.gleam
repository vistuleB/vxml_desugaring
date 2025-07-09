import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  let #(string_pairs, forbidden_parents) = inner
  infra.find_replace_in_node_transform_version(_, string_pairs)
  |> n2t.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(List(#(String, String)), List(String))
//  ↖                        ↖
//  from/to pairs            keep_out_of

type InnerParam = Param

const name = "find_replace"
const constructor = find_replace

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// find and replace strings with other strings
pub fn find_replace(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// find and replace strings with other strings
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  [
    infra.AssertiveTestData(
      param: #([#("from", "to")], ["keep_out"]),
      source:   "
                <> root
                  <> A
                    <> B
                      <>
                        \"from a thing\"
                        \"to a thing\"
                      <> keep_out
                        <>
                          \"from a thing\"
                          \"to a thing\"
                    <> keep_out
                      <> B
                        <>
                          \"from a thing\"
                          \"to a thing\"
                ",
      expected: "
                <> root
                  <> A
                    <> B
                      <>
                        \"to a thing\"
                        \"to a thing\"
                      <> keep_out
                        <>
                          \"from a thing\"
                          \"to a thing\"
                    <> keep_out
                      <> B
                        <>
                          \"from a thing\"
                          \"to a thing\"
                ",
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}