import blamedlines
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn intersperse_children_with_spacers(
  children: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case children {
    [first, V(_, second_tag, _, _) as second, ..rest] -> {
      case dict.get(inner, second_tag) {
        Error(Nil) -> [
          first,
          ..intersperse_children_with_spacers([second, ..rest], inner)
        ]
        Ok(classname) -> {
          let blame = infra.get_blame(second)
          [
            first,
            V(blame, "div", [BlamedAttribute(blame, "class", classname)], []),
            ..intersperse_children_with_spacers([second, ..rest], inner)
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
      Ok(V(
        blame,
        tag,
        attributes,
        intersperse_children_with_spacers(children, inner),
      ))
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
  case infra.get_duplicate(list.map(param, pair.first)) {
    option.Some(guy) ->
      Error(DesugaringError(
        blamedlines.empty_blame(),
        "the list of elements to add_spacer_divs_before has duplicate: " <> guy,
      ))
    option.None -> Ok(dict.from_list(param))
  }
}

type Param =
  List(#(String,            String))
//       ↖               ↖
//       insert divs     class attribute
//       before tags     of inserted div
//       of this name
//       (except if tag is first child)

type InnerParam =
  Dict(String, String)

pub const desugarer_name = "add_spacer_divs_before"
pub const desugarer_pipe = add_spacer_divs_before

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds spacer divs before specified tags but not if they are the first child
pub fn add_spacer_divs_before(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds spacer divs before specified tags but not if they are the first child
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