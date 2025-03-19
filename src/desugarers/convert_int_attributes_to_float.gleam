import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

const ins = string.inspect

fn update_attributes(
  tag: String,
  attributes: List(BlamedAttribute),
  extra: Extra,
) -> List(BlamedAttribute) {
  list.fold(
    over: extra,
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

fn transform_param(node: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attributes, children) -> {
      Ok(V(blame, tag, update_attributes(tag, attributes, extra), children))
    }
  }
}

//**********************************
// List(#(String,                  String))
//           ↖ tag name,              ↖ attribute name,
//             matches all              matches all attributes
//             tag if set to ""         if set to ""
//
// ...will convert int to float for all attributes
// keys that match one of the entries in 'extra', per
// the matching rules above
//**********************************
type Extra =
  List(#(String, String))

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  infra.node_to_node_desugarer_factory(transform_param(_, extra))
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

pub fn convert_int_attributes_to_float(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "convert_int_attributes_to_float",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
