import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, T, V}

fn build_blamed_attributes(
  blame,
  attributes: List(#(String, String)),
) -> List(BlamedAttribute) {
  attributes
  |> list.map(fn(attr) {
    BlamedAttribute(blame, attr |> pair.first, attr |> pair.second)
  })
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, old_attributes, children) -> {
      case dict.get(inner, tag) {
        Ok(new_attributes) -> {
          Ok(V(
            blame,
            tag,
            list.flatten([
              old_attributes,
              build_blamed_attributes(blame, new_attributes),
            ]),
            children,
          ))
        }
        Error(Nil) -> Ok(vxml)
      }
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
  Ok(infra.triples_to_aggregated_dict(param))
}

type Param =
  List(#(String, String, String))
//       ↖      ↖       ↖
//       tag    attr    value

type InnerParam =
  Dict(String, List(#(String, String)))

const name = "add_attributes"
const constructor = add_attributes

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds attributes to tags
pub fn add_attributes(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// adds attributes to tags
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