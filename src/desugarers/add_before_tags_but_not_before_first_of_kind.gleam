import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn add_in_list(
  previous_tags: List(String),
  upcoming: List(VXML), 
  inner: InnerParam,
) -> List(VXML) {
  case upcoming {
    [] -> []
    [T(_, _) as first, ..rest] -> [first, ..add_in_list(previous_tags, rest, inner)]
    [V(_, tag, _, _) as first, ..rest] -> {
      case dict.get(inner, tag) {
        Error(_) -> [first, ..add_in_list(previous_tags, rest, inner)]
        Ok(tag_and_attributes) -> {
          case list.contains(previous_tags, tag) {
            False -> [first, ..add_in_list([tag, ..previous_tags], rest, inner)]
            True -> {
              let blame = infra.blame_us("add_before_tags_but_not_before_first_of_kind")
              let new_node = V(
                blame,
                tag_and_attributes.0,
                list.map(tag_and_attributes.1, fn(kv) { BlamedAttribute(blame, kv.0, kv.1)}),
                [],
              )
              [
                new_node,
                first,
                ..add_in_list(previous_tags, rest, inner),
              ]
            }
          }
        }
      }
    }
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    V(_, _, _, children) ->
      Ok(V(..node, children: add_in_list([], children, inner)))
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
  Ok(infra.triples_to_dict(param))
}

type Param =
  List(#(String,         String,           List(#(String, String))))
//       ↖              ↖                ↖
//       insert divs    tag name         attributes
//       before tags    of new element
//       of this name
//       (except if it's the first occurrence of the same kind)

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

pub const desugarer_name = "add_before_tags_but_not_before_first_of_kind"
pub const desugarer_pipe = add_before_tags_but_not_before_first_of_kind

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// adds new elements before specified tags but
/// not before the first occurrence of the same kind
pub fn add_before_tags_but_not_before_first_of_kind(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds new elements before specified tags but
/// not before the first occurrence of the same kind
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
