import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  node: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case infra.use_list_pair_as_dict(inner, tag) {
        Error(Nil) -> Ok([node])
        Ok(forbidden) -> {
          let ancestor_names = list.map(ancestors, infra.get_tag)
          case list.any(ancestor_names, list.contains(forbidden, _)) {
            True -> Ok(children)
            False -> Ok([node])
          }
        }
      }
    _ -> Ok([node])
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(vxml: VXML, s1: List(VXML), s2: List(VXML), s3: List(VXML), s4: List(VXML)) {
    transform(vxml, s1, s2, s3, s4, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(#(String, List(String)))
//              ↖       ↖
//              tag to  list of ancestor names
//              be      that will cause tag to unwrap
//              unwrapped

type InnerParam = Param

pub const desugarer_name = "unwrap_when_descendant_of"
pub const desugarer_pipe = unwrap_when_descendant_of

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// unwraps tags that are the descendant of
/// one of a stipulated list of tag names
pub fn unwrap_when_descendant_of(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.Some(ins(param)),
    "
/// unwraps tags that are the descendant of
/// one of a stipulated list of tag names
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