import blamedlines
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn intersperse_children_with_spacers(
  children: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, second, ..rest] -> {
      case dict.get(inner, first_tag) {
        Error(Nil) -> [
          first,
          ..intersperse_children_with_spacers([second, ..rest], inner)
        ]
        Ok(classname) -> {
          let blame = infra.get_blame(first)
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
        "the list of elements to add_spacer_divs_after has duplicate: " <> guy,
      ))
    option.None -> Ok(dict.from_list(param))
  }
}

type Param =
  List(#(String,           String))
//       ↖               ↖
//       insert divs     class attribute
//       after tags      of inserted div
//       of this name
//       (except if tag is last child)

type InnerParam =
  Dict(String, String)

/// adds spacer divs after specified tags but not if they are the last child
pub fn add_spacer_divs_after(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "add_spacer_divs_after",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds spacer divs after specified tags but not if they are the last child
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}