import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn add_in_list(children: List(VXML), param: InnerParam) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, T(_, _) as second, ..rest] -> {
      case dict.get(param, first_tag) {
        Error(Nil) -> [first, ..add_in_list([second, ..rest], param)]
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
            second,
            ..add_in_list(rest, param)
          ]
        }
      }
    }
    [first, ..rest] -> [first, ..add_in_list(rest, param)]
    [] -> []
  }
}

fn transform(node: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) ->
      Ok(V(blame, tag, attributes, add_in_list(children, param)))
    _ -> Ok(node)
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(infra.triples_to_dict(param))
}

type Param =
  List(#(String, String, List(#(String, String))))

//**********************************
// type Param = List(String,                         String,                List(#(String, String))))
//                       ↖ insert new element          ↖ tag name             ↖attributes for
//                         between this tag              for new element       new element
//                         and following text node
//**********************************

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

pub fn add_between_tag_and_text_node(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_between_tag_and_text_node",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
