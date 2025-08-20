import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}
import blamedlines as bl

fn add_in_list(
  vxmls: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case vxmls {
    [V(_, tag, _, _) as first, ..rest] if tag == inner.0 ->
      [inner.1, first, ..add_in_list(rest, inner)]

    [first, ..rest] ->
      [first, ..add_in_list(rest, inner)]

    _ -> vxmls
  }
}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> VXML {
  case node {
    V(_, _, _, children) ->
      V(..node, children: add_in_list(children, inner))
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
  #(
    param.0,
    infra.v_attrs_constructor(desugarer_blame, param.1, param.2),
  )
  |> Ok
}

type Param = #(String,        String,          List(#(String, String)))
//             ↖              ↖                ↖
//             insert divs    tag name         attributes
//             before tags    of new element
//             of this name
type InnerParam = #(String, VXML)

const name = "add_before"
const constructor = add_before
const desugarer_blame = bl.Des([], name)

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds a new element before each occurrence of a
/// specified tag
pub fn add_before(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// adds a new element before each occurrence of a
/// specified tag
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