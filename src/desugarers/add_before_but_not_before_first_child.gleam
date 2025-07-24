import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, V}
import blamedlines.{type Blame}

fn add_in_list(children: List(VXML), inner: InnerParam) -> List(VXML) {
  case children {
    [first, V(_, tag, _, _) as second, ..rest] if tag == inner.0 -> [
      first,
      V(
        inner.3,
        inner.1,
        inner.2,
        [],
      ),
      ..add_in_list([second, ..rest], inner)
    ]
    [first, ..rest] -> [first, ..add_in_list(rest, inner)]
    [] -> children
  }
}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> VXML {
  case node {
    V(_, _, _, children) -> V(..node, children: add_in_list(children, inner))
    _ -> node
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let blame = infra.blame_us("add_before_tag_but_not_first_child_tags_no_list")
  #(
    param.0,
    param.1,
    list.map(
      param.2,
      fn(pair) { BlamedAttribute(blame, pair.0, pair.1) }
    ),
    blame,
  )
  |> Ok
}

type Param = #(String,        String,          List(#(String, String)))
//             ↖              ↖                ↖
//             insert divs    tag name         attributes
//             before tags    of new element
//             of this name
//             (except if tag is first child)
type InnerParam = #(String, String, List(vxml.BlamedAttribute), Blame)

const name = "add_before_but_not_before_first_child"
const constructor = add_before_but_not_before_first_child

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds new elements before specified tags but not 
/// if they are the first child
pub fn add_before_but_not_before_first_child(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// adds new elements before specified tags but not 
/// if they are the first child
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