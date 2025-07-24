import gleam/option
import gleam/string.{inspect as ins}
import gleam/list
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms.{type TrafficLight, Continue, GoBack} as n2t
import vxml.{type VXML, V, T, BlamedContent}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> #(VXML, TrafficLight) {
  case node {
    V(_, tag, _, _) if tag == inner.0 -> {
      // return early if we have a child of tag child_tag == inner.1:
      use _ <- infra.on_ok_on_error(
        infra.children_with_tag(node, inner.1) |> list.first,
        fn(_) {#(node, GoBack)},
      )

      // return early if we don't have a attribute_key == inner.2:
      use attribute <- infra.on_error_on_ok(
        infra.v_all_attributes_with_key(node, inner.2) |> list.first,
        fn (_) {#(node, GoBack)},
      )

      #(
        V(
          ..node,
          children: [
            V(
              infra.blame_us("auto_generate_child_if_missing_from_attribute"),
              inner.1,
              [],
              [T(attribute.blame, [BlamedContent(attribute.blame, attribute.value)])],
            ),
            ..node.children,
          ]
        ),
        GoBack,
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
  |> n2t.early_return_one_to_one_no_error_nodemap_2_desugarer_transform_with_forbidden(inner.3)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String,     List(String))
//             ↖       ↖       ↖           ↖
//             parent  child   attribute   stay outside of
//             tag     tag                 these subtrees
type InnerParam = Param

const name = "auto_generate_child_if_missing_from_attribute__outside"
const constructor = auto_generate_child_if_missing_from_attribute__outside

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Given first 3 arguments
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
/// 
/// Stays outside of trees rooted at tags in last
/// argument given to function.
pub fn auto_generate_child_if_missing_from_attribute__outside(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// Given first 3 arguments
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
/// 
/// Stays outside of trees rooted at tags in last
/// argument given to function.
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
