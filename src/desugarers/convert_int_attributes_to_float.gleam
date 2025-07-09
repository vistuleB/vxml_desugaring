import gleam/int
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, T, V}

fn update_attributes(
  tag: String,
  attributes: List(BlamedAttribute),
  inner: InnerParam,
) -> List(BlamedAttribute) {
  list.fold(
    over: inner,
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

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attributes, children) -> {
      Ok(V(blame, tag, update_attributes(tag, attributes, inner), children))
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,              String))
//       ↖                    ↖
//       tag name,            attribute name,
//       matches all          matches all attributes
//       tag if set to ""     if set to ""

type InnerParam = Param

const name = "convert_int_attributes_to_float"
const constructor = convert_int_attributes_to_float

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// converts int to float for all attributes keys
/// that match one of the entries in 'param', per
/// the matching rules above
pub fn convert_int_attributes_to_float(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// converts int to float for all attributes keys
/// that match one of the entries in 'param', per
/// the matching rules above
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