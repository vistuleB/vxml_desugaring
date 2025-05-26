import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, BlamedAttribute, V}

const ins = string.inspect

fn add_in_list(children: List(VXML), inner_param: InnerParam) -> List(VXML) {
  case children {
    [first, V(blame, tag, _, _) as second, ..rest] -> {
      case dict.get(inner_param, tag) {
        Error(Nil) -> [first, ..add_in_list([second, ..rest], inner_param)]
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
            ..add_in_list([second, ..rest], inner_param)
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
      Ok(V(blame, tag, attributes, add_in_list(children, inner_param)))
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
  Ok(param |> infra.triples_to_dict)
}

//**********************************
// type Param = List(#(String,                  String,            List(#(String, String))))
//                       ↖ insert divs          ↖ tag name         ↖ attributes 
//                         before tags            of new element
//                         of this name
//                         (except if tag is first child)
//**********************************
type Param =
  List(#(String, String, List(#(String, String))))

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

pub fn add_before_tags_but_not_first_child_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_before_tags_but_not_first_child_tags",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> desugarer_factory(inner_param)
    }
  )
}