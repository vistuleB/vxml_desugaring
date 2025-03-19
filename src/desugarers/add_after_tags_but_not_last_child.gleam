import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, BlamedAttribute, V}

const ins = string.inspect

fn add_in_list(children: List(VXML), param: Param) -> List(VXML) {
  case children {
    [first, V(blame, tag, _, _) as second, ..rest] -> {
      case dict.get(param, tag) {
        Error(Nil) -> [first, ..add_in_list([second, ..rest], param)]
        Ok(#(new_element_tag, new_element_attributes)) -> {
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
            ..add_in_list([second, ..rest], param)
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
        add_in_list(children |> list.reverse, param) |> list.reverse,
      ))
    _ -> Ok(node)
  }
}

fn param(extra: Extra) -> Param {
  extra |> infra.triples_to_dict
}

type Param =
  Dict(String, #(String, List(#(String, String))))

//**********************************
// type Extra = List(#(String,                  String,            List(#(String, String))))
//                       ↖ insert after          ↖ tag name         ↖ attributes 
//                         tag of this             of new element
//                         name (except 
//                         if last child)
//**********************************
type Extra =
  List(#(String, String, List(#(String, String))))

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

pub fn add_after_tags_but_not_first_child_tags(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_after_tags_but_not_first_child_tags",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra |> param),
  )
}
