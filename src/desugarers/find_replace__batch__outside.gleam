import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  infra.find_replace_in_node(_, inner.0)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform_with_forbidden(inner.1)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(#(String, String)), List(String))
//             ↖                        ↖
//             from/to pairs            keep_out_of
type InnerParam = Param

const name = "find_replace__batch__outside"
const constructor = find_replace__batch__outside

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// find and replace strings with other strings
pub fn find_replace__batch__outside(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
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