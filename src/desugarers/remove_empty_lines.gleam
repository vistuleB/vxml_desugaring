import gleam/list
import gleam/option
import infrastructure.{ type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError } as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn transform(
  node: VXML,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, _, _, _) -> Ok([node])
    T(blame, lines) -> {
      let lines = list.filter(lines, fn (b) { b.content != "" })
      case list.is_empty(lines) {
        True -> Ok([])
        False -> Ok([T(blame, lines)])
      }
    }
  }
}

fn transform_factory(_: InnerParam) -> n2t.NodeToNodesTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.node_to_nodes_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

const name = "remove_empty_lines"
const constructor = remove_empty_lines

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// for each text node, removes each line whose
/// content is the empty string & destroys
/// text nodes that end up with 0 lines
pub fn remove_empty_lines(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// for each text node, removes each line whose
/// content is the empty string & destroys
/// text nodes that end up with 0 lines
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
