import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

fn concatenate_tags_in_list(vxmls: List(VXML), inner: InnerParam) -> List(VXML) {
  case vxmls {
    [] -> []
    [V(_, tag1, _, _) as v1, V(_, tag2, _, _) as v2, ..rest] -> {
      case tag1 == tag2 && list.contains(inner, tag1) {
        True -> [v1, ..concatenate_tags_in_list(rest, inner)]
        False -> [v1, ..concatenate_tags_in_list([v2, ..rest], inner)]
      }
    }
    [first, ..rest] -> [first, ..concatenate_tags_in_list(rest, inner)]
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs, children |> concatenate_tags_in_list(inner)))
    _ -> Ok(node)
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

type Param = List(String)

type InnerParam = Param

const name = "concatenate_tags"
const constructor = concatenate_tags

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// concatenates adjacent tags with the same name
pub fn concatenate_tags(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// concatenates adjacent tags with the same name
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