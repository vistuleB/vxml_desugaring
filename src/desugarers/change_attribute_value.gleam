import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, T, V}

fn replace_value(value: String, replacement: String) -> String {
  string.replace(replacement, "()", value)
}

fn update_attribute(
  attr: BlamedAttribute,
  inner: InnerParam,
) -> BlamedAttribute {
  case list.find(inner, fn(x) {x.0 == attr.key}) {
    Ok(#(_, replacement)) -> BlamedAttribute(..attr, value: replace_value(attr.value, replacement))
    _ -> attr
  }
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, _, _, _) -> {
      Ok(V(..vxml, attributes: list.map(vxml.attributes, update_attribute(_, inner))))
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,         String))
//       ↖               ↖
//       attribute key   replacement of attribute value string
//                       "()" can be used to echo the current value
//                       ex:
//                         current value: image/img.png
//                         replacement: /()
//                         result: /image/img.png

type InnerParam = Param

const name = "change_attribute_value"
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
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}