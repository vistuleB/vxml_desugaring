import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/option.{None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn intersperse_children_with_spacers(
  children: List(VXML),
  param: InnerParam,
) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, V(_, second_tag, _, _) as second, ..rest] -> {
      case dict.get(param, #(first_tag, second_tag)) {
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

fn transform(node: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type InnerParam =
  Dict(#(String, String), String)

//**********************************
// type Param = List(#(String,                String),     String))
//                       ↖ insert divs between ↗             ↖ class name         
//                          adjacent siblings                  for inserted div
//                         of these two names
//**********************************
type Param =
  List(#(#(String, String), String))

pub fn add_spacer_divs_between(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_spacer_divs_between",
      Some(ins(param)),
      "...",
    ),
    desugarer: case infra.dict_from_list_with_desugaring_error(param) {
      Error(err) -> fn(_) { Error(err) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
