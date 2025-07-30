import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    T(_, _) -> vxml
    V(_, tag, _, _) -> case list.contains(inner, tag) {
      True ->
        vxml
        |> infra.v_trim_start
        |> infra.v_trim_end
      False -> vxml
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)
type InnerParam = Param

const name = "trim__batch"
const constructor = trim__batch

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Removes starting spaces from first and ending
/// spaces from last child of nodes with specified
/// tags if those children are T-nodes. The removal 
/// of spaces includes the removal of empty lines
/// and the deletion of the entire T-node if no
/// lines remain, in which case the process
/// continues with the next or previous T-node, if
/// any.
pub fn trim__batch(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(param |> infra.list_param_stringifier),
    option.None,
    "
/// Removes starting spaces from first and ending
/// spaces from last child of nodes with specified
/// tag if those children are T-nodes. The removal 
/// of spaces includes the removal of empty lines
/// and the deletion of the entire T-node if no
/// lines remain, in which case the process
/// continues with the next or previous T-node, if
/// any.
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