import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn add_in_list(children: List(VXML), inner: InnerParam) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, V(_, second_tag, _, _) as second, ..rest] -> {
      case dict.get(inner, #(first_tag, second_tag)) {
        Error(Nil) -> [first, ..add_in_list([second, ..rest], inner)]
        Ok(#(new_element_tag, new_element_attributes)) -> {
          let blame = infra.get_blame(first)
          [
            first,
            V(
              blame,
              new_element_tag,
              list.map(new_element_attributes, fn(pair) {
                BlamedAttribute(blame, pair |> pair.first, pair |> pair.second)
              }),
              [],
            ),
            ..add_in_list([second, ..rest], inner)
          ]
        }
      }
    }
    _ -> children
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(blame, tag, attributes, add_in_list(children, inner)))
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
  List(#(#(String,           String), String,             List(#(String, String))))
//         ↖                ↖        ↖                    ↖
//         insert divs      ↗        tag name             attributes for
//         between adjacent          for new element      new element
//         siblings of these
//         two names

type InnerParam =
  Dict(#(String, String), #(String, List(#(String, String))))

pub const desugarer_name = "add_between_tags"
pub const desugarer_pipe = add_between_tags

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// adds new elements between adjacent tags of specified types
pub fn add_between_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds new elements between adjacent tags of specified types
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