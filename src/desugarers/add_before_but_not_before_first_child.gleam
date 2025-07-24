import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn add_in_list(
  vxmls: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case vxmls {
    [first, V(_, tag, _, _) as second, ..rest] if tag == inner.0 ->
      [first, inner.1, ..add_in_list([second, ..rest], inner)]
    [first, second, ..rest] ->
      [first, ..add_in_list([second, ..rest], inner)]
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
  let v = infra.blame_tag_attrs_2_v(
    "add_before_but_not_before_first_child",
    param.1,
    param.2,
  )
  Ok(#(param.0, v))
}

type Param = #(String,        String,          List(#(String, String)))
//             ↖              ↖                ↖
//             insert divs    tag name         attributes
//             before tags    of new element
//             of this name
//             (except if tag is first child)
type InnerParam = #(String, VXML)

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