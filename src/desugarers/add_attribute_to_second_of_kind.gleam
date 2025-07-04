import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn transform(
  node: VXML,
  previous_unmapped_siblings: List(VXML),
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node, previous_unmapped_siblings {
    V(_, tag, attrs, _), [V(_, prev_tag, _, _), ..] if tag == inner.0 && prev_tag == inner.0 -> {
      let new_attr = BlamedAttribute(infra.blame_us("add_attribute_to_second_of_kind"), inner.1, inner.2)
      Ok(V(..node, attributes: list.append(attrs, [new_attr])))
    }
    _, _ -> Ok(node)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeFancyTransform {
  fn(node, _, prev_siblings, _, _) {
    transform(node, prev_siblings, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String, String)
//  ↖       ↖       ↖
//  tag     key     value

type InnerParam = Param

pub const desugarer_name = "add_attribute_to_second_of_kind"
pub const desugarer_pipe = add_attribute_to_second_of_kind

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// Adds the specified attribute-value pair to
/// nodes with the given tag name
/// when the previous sibling is also a node with
/// the same tag name
pub fn add_attribute_to_second_of_kind(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// Adds the specified attribute-value pair to
/// nodes with the given tag name
/// when the previous sibling is also a node with
/// the same tag name
      ",
    ),
    desugarer: case param_to_inner_param(param) {
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
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}
