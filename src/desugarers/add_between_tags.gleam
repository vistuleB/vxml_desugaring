import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn add_in_list(children: List(VXML), inner_param: InnerParam) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, V(_, second_tag, _, _) as second, ..rest] -> {
      case dict.get(inner_param, #(first_tag, second_tag)) {
        Error(Nil) -> [first, ..add_in_list([second, ..rest], inner_param)]
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
  Ok(infra.triples_to_dict(param))
}

//**********************************
// type Param = List(#(String,                String),     String,                 List(#(String, String))))
//                       ↖ insert divs between ↗             ↖ tag name             ↖ attributes for
//                          adjacent siblings                  for new element        new element
//                         of these two names
//**********************************
type Param =
  List(#(#(String, String), String, List(#(String, String))))

type InnerParam =
  Dict(#(String, String), #(String, List(#(String, String))))

pub fn add_between_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_between_tags",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> desugarer_factory(inner_param)
    }
  )
}