import gleam/option
import infrastructure.{ type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError } as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, BlamedContent}

fn nodemap(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, [BlamedContent(_, "")]) -> Ok([])
    _ -> Ok([node])
  }
}

fn nodemap_factory(_: InnerParam) -> n2t.OneToManyNodeMap {
  nodemap
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "remove_text_nodes_with_singleton_empty_line"
const constructor = remove_text_nodes_with_singleton_empty_line

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// removes text nodes containing a single line
/// consisting of an empty string
pub fn remove_text_nodes_with_singleton_empty_line() -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// removes text nodes containing a single line
/// consisting of an empty string
    ",
    case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(name, assertive_tests_data(), constructor)
}
