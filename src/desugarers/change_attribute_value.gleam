import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn replace_value(value: String, replacement: String) -> String {
  string.replace(replacement, "()", value)
}

fn update_attributes(
  attributes: List(BlamedAttribute),
  param: InnerParam,
) -> List(BlamedAttribute) {
  case attributes {
    [] -> attributes
    [first, ..rest] -> {
      case
        param
        |> list.find(fn(x) {
          let #(key, _) = x
          key == first.key
        })
      {
        Ok(#(_, replacement)) -> {
          [
            BlamedAttribute(
              ..first,
              value: replace_value(first.value, replacement),
            ),
            ..update_attributes(rest, param)
          ]
        }
        Error(_) -> [first, ..update_attributes(rest, param)]
      }
    }
  }
}

fn change_attribute_value_param_transform(
  vxml: VXML,
  param: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      Ok(V(blame, tag, update_attributes(attributes, param), children))
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  change_attribute_value_param_transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(#(String,           String))
//                  ↖ attribute key   ↖ replacement of attribute value string
//                                      "()" can be used to echo the current value
//                                      ex:
//                                        current value: image/img.png
//                                        replacement: /()
//                                        result: /image/img.png

type InnerParam = Param

/// Used for changing the value of an attribute.
/// Takes an attribute key and a replacement
/// string in which "()" is used as a stand-in
/// for the current value. For example, replacing
/// attribute value "images/img.png" with the
/// replacement string "/()" will result in the
/// new attribute value "/images/img.png"
pub fn change_attribute_value(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "change_attribute_value",
      option.Some(string.inspect(param)),
      "
Used for changing the value of an attribute.
Takes an attribute key and a replacement
string in which \"()\" is used as a stand-in
for the current value. For example, replacing
attribute value \"images/img.png\" with the
replacement string \"/()\" will result in the
new attribute value \"/images/img.png\"
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
