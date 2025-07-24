import gleam/option
import gleam/string.{inspect as ins}
import group_replacement_splitting as grs
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNoErrorNodeMap {
  grs.split_if_t_with_replacement_nodemap(_, inner.0)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_many_no_error_nodemap_2_desugarer_transform_with_forbidden(inner.1)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(List(grs.RegexpWithGroupReplacementInstructions), List(String))
//            ↖                                                   ↖
//            replacement_instructions                            forbidden_parents
type InnerParam = Param

const name = "split_with_replacement_instructions_plural"
const constructor = split_with_replacement_instructions_plural

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// splits text nodes by regexp with group-by-group
/// replacement instructions
pub fn split_with_replacement_instructions_plural(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// splits text nodes by regexp with group-by-group
/// replacement instructions
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
