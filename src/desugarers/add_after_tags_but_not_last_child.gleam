import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

const ins = string.inspect

fn add_in_list(children: List(VXML), param: InnerParam) -> List(VXML) {
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

fn transform(node: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
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
  List(#(String,          String,           List(#(String, String))))
//       ↖ insert after   ↖ tag name        ↖ attributes
//         tag of this      of new element
//         name (except
//         if last child)

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

pub fn add_after_tags_but_not_first_child_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "add_after_tags_but_not_first_child_tags",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
