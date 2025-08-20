import gleam/option
import gleam/string.{inspect as ins}
import gleam/list
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, type TrafficLight, Continue, GoBack} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V, T, BlamedContent}
import blamedlines as bl

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> #(VXML, TrafficLight) {
  let #(parent_tag, child_tag, attribute_key) = inner
  case node {
    V(_, tag, _, _) if tag == parent_tag -> {
      // return early if we have a child of tag child_tag:
      use _ <- infra.on_ok_on_error(
        infra.children_with_tag(node, child_tag) |> list.first,
        fn(_) {#(node, GoBack)},
      )

      // return early if we don't have a attribute_key :
      use attribute <- infra.on_error_on_ok(
        infra.v_all_attributes_with_key(node, attribute_key) |> list.first,
        fn (_) {#(node, GoBack)},
      )

      #(
        V(
          ..node,
          children: [
            V(
              desugarer_blame,
              child_tag,
              [],
              [T(attribute.blame, [BlamedContent(attribute.blame, attribute.value)])],
            ),
            ..node.children,
          ]
        ),
        GoBack
      )
    }
    _ -> #(node, Continue)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.EarlyReturnOneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.early_return_one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)
//             ↖       ↖       ↖
//             parent  child   attribute
//             tag     tag
type InnerParam = Param

const name = "auto_generate_child_if_missing_from_attribute"
const constructor = auto_generate_child_if_missing_from_attribute
const desugarer_blame = bl.Des([], name)

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Given arguments
/// ```
/// parent_tag, child_tag, attribute_key
/// ```
/// will, for each node of tag `parent_tag`,
/// generate, if the node has no existing children
/// tag `child_tag`, by using the value of 
/// attribute_key as the contents of the child of 
/// tag child_tag. If no such attribute exists, does
/// nothing to the node of tag parent_tag.
/// 
/// Early-returns from subtree rooted at parent_tag.
pub fn auto_generate_child_if_missing_from_attribute(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// Given arguments
/// ```
/// parent_tag, child_tag, attribute_key
/// ```
/// will, for each node of tag `parent_tag`,
/// generate, if the node has no existing children
/// tag `child_tag`, by using the value of 
/// attribute_key as the contents of the child of 
/// tag child_tag. If no such attribute exists, does
/// nothing to the node of tag parent_tag.
/// 
/// Early-returns from subtree rooted at parent_tag.
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
