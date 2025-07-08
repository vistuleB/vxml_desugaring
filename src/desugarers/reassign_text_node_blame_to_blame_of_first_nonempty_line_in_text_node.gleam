import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, T}

fn transform(
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

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub const desugarer_name = "reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node"
pub const desugarer_pipe = reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// reassigns text node blame to the blame of the
/// first nonempty line in the text node
pub fn reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node() -> Pipe {
  Pipe(
    desugarer_name,
    option.None,
    "
/// reassigns text node blame to the blame of the
/// first nonempty line in the text node
    ",
    case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(desugarer_name, assertive_tests_data(), desugarer_pipe)
}
