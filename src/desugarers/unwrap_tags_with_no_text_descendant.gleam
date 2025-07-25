import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn has_text_descendant(child: VXML) {
  let assert V(_, _, _, children) = child
  // do in DFS order:
  {
    list.any(children, infra.is_text_node) ||
    list.any(children, has_text_descendant)
  }
}

fn is_text_or_has_text_descendant(node: VXML) {
  infra.is_text_node(node) || has_text_descendant(node)
}

// fn has_unique_child_of_tag(node: VXML, tags: List(String)) -> Bool {
//   let assert V(_, _, _, children) = node
//   case children {
//     [singleton] -> infra.is_v_and_tag_is_one_of(singleton, tags)
//     _ -> False
//   }
// }

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) -> {
      case list.contains(inner, tag), list.any(children, is_text_or_has_text_descendant) {
        True, False -> Ok(children)
        _, _ -> Ok([node])
      }
    }
    _ -> Ok([node])
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_many_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)
type InnerParam = List(String)

const name = "unwrap_tags_with_no_text_descendant"
const constructor =  unwrap_tags_with_no_text_descendant

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// for a specified list of tag strings, unwraps
/// nodes with tags from the list if the node does
/// not have a text child descendant
pub fn unwrap_tags_with_no_text_descendant(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// for a specified list of tag strings, unwraps
/// nodes with tags from the list if the node does
/// not have a text child descendant
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