import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, tag, atts, children) -> {
      case list.find(inner, fn(pair) { pair |> pair.first == tag }) {
        Error(Nil) -> Ok(vxml)
        Ok(#(_, #(start_tag, end_tag))) -> {
          Ok(V(
            blame,
            tag,
            atts,
            [
              [V(blame, start_tag, [], [])],
              children,
              [V(blame, end_tag, [], [])],
            ]
            |> list.flatten,
          ))
        }
      }
    }
    T(_, _) -> Ok(vxml)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> infra.triples_to_pairs
  |> Ok
}

type Param =
  List(#(String, String, String))
//       ↖      ↖       ↖
//       tag    start   end
//              tag     tag

type InnerParam =
  List(#(String, #(String, String)))

const name = "insert_bookend_tags"
const constructor = insert_bookend_tags

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// inserts bookend tags at the beginning and end of
/// specified tags
pub fn insert_bookend_tags(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// inserts bookend tags at the beginning and end of
/// specified tags
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