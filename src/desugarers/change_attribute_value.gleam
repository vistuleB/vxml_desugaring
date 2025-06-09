import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn replace_value(value: String, replacement: String) -> String {
  string.replace(replacement, "()", value)
}

fn update_attributes(
  attributes: List(BlamedAttribute),
  inner: InnerParam,
) -> List(BlamedAttribute) {
  case attributes {
    [] -> attributes
    [first, ..rest] -> {
      case
        inner
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
            ..update_attributes(rest, inner)
          ]
        }
        Error(_) -> [first, ..update_attributes(rest, inner)]
      }
    }
  }
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      Ok(V(blame, tag, update_attributes(attributes, inner), children))
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
  List(#(String,           String))
//       ↖                ↖
//       attribute key     replacement of attribute value string
//                         "()" can be used to echo the current value
//                         ex:
//                           current value: image/img.png
//                           replacement: /()
//                           result: /image/img.png

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
      desugarer_name: "change_attribute_value",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// Used for changing the value of an attribute.
/// Takes an attribute key and a replacement
/// string in which \"()\" is used as a stand-in
/// for the current value. For example, replacing
/// attribute value \"images/img.png\" with the
/// replacement string \"/()\" will result in the
/// new attribute value \"/images/img.png\"
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}