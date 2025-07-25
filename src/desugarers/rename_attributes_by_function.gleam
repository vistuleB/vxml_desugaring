import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V, type BlamedAttribute, BlamedAttribute}

fn rename_attribute_key(attr: BlamedAttribute, transform_fn: fn(String) -> String) -> BlamedAttribute {
  BlamedAttribute(..attr, key: transform_fn(attr.key))
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, _, attrs, _) -> {
      Ok(V(..vxml, attributes: list.map(attrs, rename_attribute_key(_, inner))))
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
  fn(String) -> String

type InnerParam = Param

const name = "rename_attributes_by_function"
const constructor =  rename_attributes_by_function

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// renames attribute keys using a provided
/// transformation function
pub fn rename_attributes_by_function(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    option.None,
    "
/// renames attribute keys using a provided
/// transformation function
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
  [
    infra.AssertiveTestData(
      param: infra.kabob_case_to_camel_case,
      source:   "
                <> div
                  data-test=value1
                  my-attr=value2
                  another-long-name=value3
                ",
      expected: "
                <> div
                  dataTest=value1
                  myAttr=value2
                  anotherLongName=value3
                "
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
