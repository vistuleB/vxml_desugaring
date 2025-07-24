import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms.{type TrafficLight, GoBack, Continue} as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, V}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> #(VXML, TrafficLight) {
  case vxml {
    V(_, tag, attrs, _) if tag == inner.0 -> {
      #(
        V(..vxml, attributes: list.append(attrs, [inner.1])),
        GoBack,
      )
    }
    _ -> #(vxml, Continue)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.EarlyReturnOneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.early_return_one_to_one_no_error_nodemap_2_desugarer_transform_with_forbidden(inner.2)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  #(
    param.0,
    BlamedAttribute(
      infra.blame_us("add_attrs_no_list"),
      param.1,
      param.2,
    ),
    param.3,
  )
  |> Ok
}

type Param = #(String, String, String, List(String))
//             ↖       ↖       ↖       ↖
//             tag     attr    value   ...outside of
//                                     subtrees rooted
//                                     at these tags
type InnerParam = #(String, BlamedAttribute, List(String))

const name = "append_attribute__outside"
const constructor = append_attribute__outside

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// add a specific key-value pair to all tags of a
/// given name and early-return after tag is added,
/// while not entering subtrees specified by the 
/// last argument to the desugarer
pub fn append_attribute__outside(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// add a specific key-value pair to all tags of a
/// given name and early-return after tag is added,
/// while not entering subtrees specified by the 
/// last argument to the desugarer
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