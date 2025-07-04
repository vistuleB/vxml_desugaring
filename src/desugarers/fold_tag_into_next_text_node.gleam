import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedContent, T, V}

fn prepend_to_next_text_node(text: String, node: VXML) -> List(VXML) {
  case node {
    T(_, _) -> [infra.t_start_insert_text(node, text)]
    V(b, _, _, _) as v -> [T(b, [BlamedContent(b, text)]), v]
  }
}

fn transform(
  vxml: VXML,
  _: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  let #(tag_to_fold, fold_as) = inner

  case vxml {
    V(_, tag, _, _) if tag == tag_to_fold -> Ok([])
    _ -> {
      case previous_siblings_before_mapping {
        [V(_, tag, _, _), ..] if tag == tag_to_fold -> {
          let vxmls = prepend_to_next_text_node(fold_as, vxml)
          Ok(vxmls)
        }
        _ -> Ok([vxml])
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    transform(node, ancestors, s1, s2, s3, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String)
//  ↖       ↖
//  tag     fold
//  to      as
//  fold    text

type InnerParam = Param

pub const desugarer_name = "fold_tag_into_next_text_node"
pub const desugarer_pipe = fold_tag_into_next_text_node

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// folds specified tags into the next text node as text content
pub fn fold_tag_into_next_text_node(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// folds specified tags into the next text node as text content
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