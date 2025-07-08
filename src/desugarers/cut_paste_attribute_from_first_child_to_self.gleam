import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, Pipe} as infra
import vxml.{type VXML, V, type BlamedAttribute}

/// return option of
/// - attribute with key `key`
/// - modified children (with removed attribute)
fn check_first_child(children: List(VXML), key: String)
-> Option(#(BlamedAttribute, List(VXML))) {
  use #(first, rest) <- infra.on_error_on_ok(infra.first_rest(children), fn(_){None})
  use <- infra.on_t_on_v_no_deconstruct(first, fn(_, _){None})
  let assert V(_, _, _, _) = first
  use attribute <- infra.on_error_on_ok(
    list.find(first.attributes, fn(att) {att.key == key}),
    fn(_){None},
  )
  let first = V(..first, attributes: list.filter(first.attributes, fn(att) { att.key != key }))
  Some(#(attribute, [first, ..rest]))
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, key) = inner
  case node {
    V(_, tag, _, children) if tag == parent_tag -> {
      case check_first_child(children, key) {
        option.None -> Ok(node)
        option.Some(#(att, children)) -> Ok(V(..node, attributes: list.append(node.attributes, [att]), children: children))
      }
    }
    _ -> Ok(node)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String)
//  ↖       ↖
//  parent  attribute
//  tag     key

type InnerParam = Param

pub const desugarer_name = "cut_paste_attribute_from_first_child_to_self"
pub const desugarer_pipe = cut_paste_attribute_from_first_child_to_self

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// Moves an attribute with key `key` from the
/// first child of a node with tag `parent_tag`
/// to the node itself.
/// ```
/// #Param:
/// - parent tag
/// - child tag
/// - attribute key
/// ```
pub fn cut_paste_attribute_from_first_child_to_self(param: Param) -> Pipe {
  Pipe(
    desugarer_name,
    option.Some(ins(param)),
    "
/// Moves an attribute with key `key` from the
/// first child of a node with tag `parent_tag`
/// to the node itself.
/// ```
/// #Param:
/// - parent tag
/// - child tag
/// - attribute key
/// ```
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
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}