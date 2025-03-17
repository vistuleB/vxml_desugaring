import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, BlamedAttribute, V}

const ins = string.inspect

type Param =
  Dict(String, String)

fn build_dictionary(
  blame: Blame,
  extra: Extra,
) -> Result(Param, DesugaringError) {
  case infra.get_duplicate(list.map(extra, pair.first)) {
    Some(guy) ->
      Error(DesugaringError(
        blame,
        "the list of elements to add_spacer_divs_after has duplicate: " <> guy,
      ))
    None -> Ok(dict.from_list(extra))
  }
}

fn intersperse_children_with_spacers(
  children: List(VXML),
  param: Param,
) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, second, ..rest] -> {
      case dict.get(param, first_tag) {
        Error(Nil) -> [
          first,
          ..intersperse_children_with_spacers([second, ..rest], param)
        ]
        Ok(classname) -> {
          let blame = infra.get_blame(first)
          [
            first,
            V(blame, "div", [BlamedAttribute(blame, "class", classname)], []),
            ..intersperse_children_with_spacers([second, ..rest], param)
          ]
        }
      }
    }
    _ -> children
  }
}

fn param_transform(node: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(
        blame,
        tag,
        attributes,
        intersperse_children_with_spacers(children, param),
      ))
    _ -> Ok(node)
  }
}

//**********************************
// type Extra = List(#(String,                  String))
//                       ↖ insert divs          ↖ class attribute
//                         after tags            of inserted div
//                         of this name
//                         (except if tag is last child)
//**********************************
type Extra =
  List(#(String, String))

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

pub fn add_spacer_divs_after(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("add_spacer_divs_after", Some(ins(extra)), "..."),
    desugarer: fn(root) {
      case build_dictionary(infra.get_blame(root), extra) {
        Error(err) -> Error(err)
        Ok(param) -> desugarer_factory(param)(root)
      }
    },
  )
}
