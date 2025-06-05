import gleam/dict.{type Dict}
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn intersperse_children_with_spacers(
  children: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case children {
    [V(_, first_tag, _, _) as first, V(_, second_tag, _, _) as second, ..rest] -> {
      case dict.get(inner, #(first_tag, second_tag)) {
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
  infra.dict_from_list_with_desugaring_error(param)
}

type Param =
  List(#(#(String,             String), String))
//         ↖                  ↖        ↖
//         insert divs        ↗        class name
//         between adjacent            for inserted div
//         siblings of these
//         two names

type InnerParam =
  Dict(#(String, String), String)

/// adds spacer divs between adjacent tags of specified types
pub fn add_spacer_divs_between(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "add_spacer_divs_between",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds spacer divs between adjacent tags of specified types
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}