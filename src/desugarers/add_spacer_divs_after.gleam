import blamedlines
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, BlamedAttribute, V}

const ins = string.inspect

fn intersperse_children_with_spacers(
  children: List(VXML),
  inner_param: InnerParam,
) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, second, ..rest] -> {
      case dict.get(inner_param, first_tag) {
        Error(Nil) -> [
          first,
          ..intersperse_children_with_spacers([second, ..rest], inner_param)
        ]
        Ok(classname) -> {
          let blame = infra.get_blame(first)
          [
            first,
            V(blame, "div", [BlamedAttribute(blame, "class", classname)], []),
            ..intersperse_children_with_spacers([second, ..rest], inner_param)
          ]
        }
      }
    }
    _ -> children
  }
}

fn transform(node: VXML, inner_param: InnerParam) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(
        blame,
        tag,
        attributes,
        intersperse_children_with_spacers(children, inner_param),
      ))
    _ -> Ok(node)
  }
}

fn transform_factory(inner_param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner_param)
}

fn desugarer_factory(inner_param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner_param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  case infra.get_duplicate(list.map(param, pair.first)) {
    Some(guy) ->
      Error(DesugaringError(
        blamedlines.empty_blame(),
        "the list of elements to add_spacer_divs_after has duplicate: " <> guy,
      ))
    None -> Ok(dict.from_list(param))
  }
}

//**********************************
// type Param = List(#(String,                  String))
//                       ↖ insert divs          ↖ class attribute
//                         after tags            of inserted div
//                         of this name
//                         (except if tag is last child)
//**********************************
type Param =
  List(#(String, String))

type InnerParam =
  Dict(String, String)

pub fn add_spacer_divs_after(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_spacer_divs_after",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> desugarer_factory(inner_param)
    }
  )
}