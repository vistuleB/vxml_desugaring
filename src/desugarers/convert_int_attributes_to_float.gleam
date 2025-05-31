import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn update_attributes(
  tag: String,
  attributes: List(BlamedAttribute),
  param: InnerParam,
) -> List(BlamedAttribute) {
  list.fold(
    over: param,
    from: attributes,
    with: fn(
      current_attributes: List(BlamedAttribute),
      tag_attr_name_pair: #(String, String),
    ) -> List(BlamedAttribute) {
      let #(tag_name, attr_name) = tag_attr_name_pair
      case tag_name == "" || tag_name == tag {
        False -> current_attributes
        True -> {
          list.map(
            current_attributes,
            fn(blamed_attribute: BlamedAttribute) -> BlamedAttribute {
              let BlamedAttribute(blame, key, value) = blamed_attribute
              case attr_name == "" || attr_name == key {
                False -> blamed_attribute
                True -> {
                  case int.parse(value) {
                    Error(_) -> blamed_attribute
                    Ok(z) ->
                      BlamedAttribute(blame, key, int.to_string(z) <> ".0")
                  }
                }
              }
            },
          )
        }
      }
    },
  )
}

fn transform(node: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attributes, children) -> {
      Ok(V(blame, tag, update_attributes(tag, attributes, param), children))
    }
  }
}



fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  infra.node_to_node_desugarer_factory(transform(_, param))
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,              String))
//       ↖ tag name,          ↖ attribute name,
//         matches all          matches all attributes
//         tag if set to ""     if set to ""

type InnerParam = Param

/// converts int to float for all attributes
/// keys that match one of the entries in 'param', per
/// the matching rules above
pub fn convert_int_attributes_to_float(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "convert_int_attributes_to_float",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
