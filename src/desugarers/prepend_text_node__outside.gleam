import gleam/option
import gleam/list
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, type TrafficLight, Continue, GoBack} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{ type VXML, BlamedContent, T, V }
import blamedlines as bl

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> #(VXML, TrafficLight) {
  case vxml {
    V(_, tag, _, children) if tag == inner.0 ->
      #(
        V(..vxml, children: [inner.1, ..children]),
        GoBack,
      )
    _ ->
      #(vxml, Continue)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.EarlyReturnOneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam, outside: List(String)) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.early_return_one_to_one_no_error_nodemap_2_desugarer_transform_with_forbidden(outside)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let blame = desugarer_blame
  #(
    param.0,
    T(
      blame,
      param.1
      |> string.split("\n")
      |> list.map(BlamedContent(blame, _))
    ),
  )
  |> Ok
}

type Param = #(String, String)
//             ↖       ↖   
//             tag     text
//                         
type InnerParam = #(String, VXML)

const name = "prepend_text_node__outside"
const constructor = prepend_text_node__outside
const desugarer_blame = bl.Des([], name)

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Given arguments
/// ```
/// tag, text
/// ```
/// prepends a text node wit content 'text' to nodes
/// of tag 'tag'. The newline character can be
/// included in 'text', which will be translated to
/// >1 BlamedContent.
/// 
/// Early-returns from nodes of tag 'tag'.
/// 
/// Stays outside of subtrees rooted at tags given
/// by the third argument.
pub fn prepend_text_node__outside(param: Param, outside: List(String)) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.Some(ins(outside)),
    "
/// Given arguments
/// ```
/// tag, text
/// ```
/// prepends a text node wit content 'text' to nodes
/// of tag 'tag'. The newline character can be
/// included in 'text', which will be translated to
/// >1 BlamedContent.
/// 
/// Early-returns from nodes of tag 'tag'.
/// 
/// Stays outside of subtrees rooted at tags given
/// by the third argument.
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner, outside)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestDataWithOutside(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_with_outside(name, assertive_tests_data(), constructor)
}