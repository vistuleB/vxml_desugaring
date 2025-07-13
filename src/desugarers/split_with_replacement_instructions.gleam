import gleam/option
import gleam/string.{inspect as ins}
import group_replacement_splitting as grs
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToManyNodeMap {
  let #(replacement_instructions, forbidden_parents) = inner
  grs.split_if_t_with_replacement(_, replacement_instructions)
  |> n2t.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(grs.RegexpWithGroupReplacementInstructions, List(String))
//            ↖                                            ↖
//            replacement_instructions                   forbidden_parents

type InnerParam = Param

const name = "split_with_replacement_instructions"
const constructor = split_with_replacement_instructions

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// splits text nodes by regexp with group-by-group
/// replacement instructions
pub fn split_with_replacement_instructions(param: Param) -> Desugarer {
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
