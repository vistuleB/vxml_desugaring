import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, V}

fn replace_value(value: String, replacement: String) -> String {
  string.replace(replacement, "()", value)
}

fn update_attribute(
  attr: BlamedAttribute,
  inner: InnerParam,
) -> BlamedAttribute {
  case inner.0 == attr.key {
    True -> BlamedAttribute(..attr, value: replace_value(attr.value, inner.1))
    _ -> attr
  }
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    V(_, _, attributes, _) -> V(..vxml, attributes: list.map(attributes, update_attribute(_, inner)))
    _ -> vxml
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
  Ok(param)
}

type Param = #(String,         String)
//             ↖               ↖
//             attribute key   replacement of attribute value string
//                             "()" can be used to echo the current value
//                             ex:
//                               current value: image/img.png
//                               replacement: /()
//                               result: /image/img.png
type InnerParam = Param

pub const name = "change_attribute_value"
const constructor = change_attribute_value

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Used for changing the value of an attribute.
/// Takes an attribute key and a replacement string 
/// in which "()" is used as a stand-in for the 
/// current value. For example, replacing attribute 
/// value "images/img.png" with the replacement 
/// string "/()" will result in the new attribute 
/// value "/images/img.png"
pub fn change_attribute_value(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// Used for changing the value of an attribute.
/// Takes an attribute key and a replacement string 
/// in which \"()\" is used as a stand-in for the 
/// current value. For example, replacing attribute 
/// value \"images/img.png\" with the replacement 
/// string \"/()\" will result in the new attribute 
/// value \"/images/img.png\"
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