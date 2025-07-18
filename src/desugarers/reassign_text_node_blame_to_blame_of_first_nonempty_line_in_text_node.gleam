import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T}

fn nodemap(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, contents) -> {
      use first_non_empty <- infra.on_error_on_ok(
        over: list.find(contents, fn(blamed_content) {
          !{ string.is_empty(blamed_content.content) }
        }),
        with_on_error: fn(_){ Ok(vxml) }
      )
      Ok(T(first_non_empty.blame, contents))
    }
    _ -> Ok(vxml)
  }
}

fn nodemap_factory(_: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node"
const constructor = reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// reassigns text node blame to the blame of the
/// first nonempty line in the text node
pub fn reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// reassigns text node blame to the blame of the
/// first nonempty line in the text node
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
