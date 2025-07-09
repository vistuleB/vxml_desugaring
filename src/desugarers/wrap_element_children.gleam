import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      let #(element_tags, wrap_with) = inner
      case list.contains(element_tags, tag) {
        True -> {
          let new_children =
            list.map(children, fn(x) { V(blame, wrap_with, [], [x]) })
          Ok(V(blame, tag, attributes, new_children))
        }
        False -> Ok(vxml)
      }
    }
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
  #(List(String), String)
//  ↖            ↖
//  element      wrap each
//  tags         child with

type InnerParam = Param

const name = "wrap_element_children"
const constructor = wrap_element_children

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// wraps each child of specified elements with a wrapper tag
pub fn wrap_element_children(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// wraps each child of specified elements with a wrapper tag
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