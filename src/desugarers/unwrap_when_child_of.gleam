import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      case infra.use_list_pair_as_dict(inner, tag) {
        Error(Nil) -> Ok([vxml])
        Ok(parent_tags) -> {
          case list.first(ancestors) {
            Error(Nil) -> Ok([vxml])
            Ok(parent) -> {
              let assert V(_, actual_parent_tag, _, _) = parent
              case list.contains(parent_tags, actual_parent_tag) {
                False -> Ok([vxml])
                True -> Ok(children)
              }
            }
          }
        }
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    transform(node, ancestors, s1, s2, s3, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,     List(String)))
//       ↖          ↖
//       tag to be  list of parent tag names
//       unwrapped  that will cause child to unwrap

type InnerParam = Param

pub const desugarer_name = "unwrap_when_child_of"
pub const desugarer_pipe = unwrap_when_child_of

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// unwrap nodes based on parent-child
/// relationships
pub fn unwrap_when_child_of(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.Some(ins(param)),
    "
/// unwrap nodes based on parent-child
/// relationships
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
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}