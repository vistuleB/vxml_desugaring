import gleam/option
import gleam/string.{inspect as ins}
import group_replacement_splitting as grs
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  let #(replacement_instructions, forbidden_parents) = inner
  grs.split_if_t_with_replacement_no_list_nodemap(_, replacement_instructions)
  |> n2t.prevent_one_to_many_nodemap_inside(forbidden_parents)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.fancy_one_to_many_nodemap_2_desugarer_transform
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(grs.RegexpWithGroupReplacementInstructions, List(String))
//             ↖                                           ↖
//             semantics in name                           forbidden tags
type InnerParam = Param

const name = "split_with_replacement_instructions_no_list"
const constructor = split_with_replacement_instructions_no_list

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// splits text nodes by regexp with group-by-group
/// replacement instructions; keeps out of subtrees
/// rooted at tags given by its second argument
pub fn split_with_replacement_instructions_no_list(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// splits text nodes by regexp with group-by-group
/// replacement instructions; keeps out of subtrees
/// rooted at tags given by its second argument
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
