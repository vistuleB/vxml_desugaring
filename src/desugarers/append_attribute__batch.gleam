import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, T, V}
import blamedlines as bl

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    T(_, _) -> vxml
    V(blame, tag, attributes, children) -> {
      case dict.get(inner, tag) {
        Ok(new_attributes) -> {
          V(
            blame,
            tag,
            list.flatten([
              attributes,
              new_attributes,
            ]),
            children,
          )
        }
        Error(Nil) -> vxml
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_no_error_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> list.map(
    fn(t) {
      #(t.0, BlamedAttribute(
        desugarer_blame(47),
        t.1,
        t.2,
      ))
    }
  )
  |> infra.aggregate_on_first
  |> Ok
}

type Param = List(#(String, String, String))
//                  ↖       ↖       ↖
//                  tag     key     value
type InnerParam = Dict(String, List(BlamedAttribute))

pub const name = "append_attribute__batch"
fn desugarer_blame(line_no: Int) {bl.Des([], name, line_no)}

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Takes a list of tuples of the form
/// ```
/// #(tag, key, value)
/// ```
/// and appends an attribute key=value to the list 
/// of attributes of each v-node of tag 'tag'. The 
/// 'tag' value can be repeated in the list, and all
/// attributes for that tag will be added.
pub fn constructor(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(param |> infra.list_param_stringifier),
    option.None,
    "
/// Takes a list of tuples of the form
/// ```
/// #(tag, key, value)
/// ```
/// and appends an attribute key=value to the list 
/// of attributes of each v-node of tag 'tag'. The 
/// 'tag' value can be repeated in the list, and all
/// attributes for that tag will be added.
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
