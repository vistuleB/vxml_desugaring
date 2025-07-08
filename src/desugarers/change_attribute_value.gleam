import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

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

fn transform(
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
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

pub const desugarer_name = "change_attribute_value"
pub const desugarer_pipe = change_attribute_value

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Used for changing the value of an attribute.
/// Takes an attribute key and a replacement string 
/// in which "()" is used as a stand-in for the 
/// current value. For example, replacing attribute 
/// value "images/img.png" with the replacement 
/// string "/()" will result in the new attribute 
/// value "/images/img.png"
pub fn change_attribute_value(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
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
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}