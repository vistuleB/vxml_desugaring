import gleam/dict.{type Dict}
import gleam/list
import gleam/pair
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, BlamedAttribute, V}

fn add_in_list(
  children: List(VXML),
  param: Param,
) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, V(_, second_tag, _, _) as second, ..rest] -> {
      case dict.get(param, #(first_tag, second_tag)) {
        Error(Nil) -> [
          first,
          ..add_in_list([second, ..rest], param)
        ]
        Ok(#(new_element_tag, new_element_attributes)) -> {
          let blame = infra.get_blame(first)
          [
            first,
            V(
              blame,
              new_element_tag,
              list.map(new_element_attributes, fn(pair) { BlamedAttribute(blame, pair |> pair.first, pair |> pair.second ) }),
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
        add_in_list(children, param),
      ))
    _ -> Ok(node)
  }
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param(extra: Extra) -> Param {
  extra
  |> infra.triples_to_dict
}

type Param =
  Dict(#(String, String), #(String, List(#(String, String))))

//**********************************
// type Extra = List(#(String,                String),     String,                 List(#(String, String))))
//                       ↖ insert divs between ↗             ↖ tag name             ↖ attributes for
//                          adjacent siblings                  for new element        new element
//                         of these two names
//**********************************
type Extra =
  List(#(#(String, String), String, List(#(String, String))))

pub fn add_between_tags(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("add_between_tags", Some(ins(extra)), "..."),
    desugarer: desugarer_factory(extra |> param),
  )
}
