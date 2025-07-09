import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, T, V}

fn replacer(mister: BlamedAttribute, inner: InnerParam) -> BlamedAttribute {
  BlamedAttribute(
    mister.blame,
    mister.key,
    list.fold(inner, mister.value, fn(current, pair) {
      let #(from, to) = pair
      string.replace(current, from, to)
    }),
  )
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs |> list.map(replacer(_, inner)), children))
  }
}

fn transform_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))
//       ↖      ↖
//       from   to

type InnerParam = Param

const name = "replace_in_attribute_values"
const constructor = replace_in_attribute_values

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// performs exact match find-replace in every
/// attribute value of every node using the
/// 'string.replace' function
pub fn replace_in_attribute_values(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// performs exact match find-replace in every
/// attribute value of every node using the
/// 'string.replace' function
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