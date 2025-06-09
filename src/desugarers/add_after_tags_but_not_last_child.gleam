import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn add_in_list(children: List(VXML), inner: InnerParam) -> List(VXML) {
  case children {
    [first, V(blame, tag, _, _) as second, ..rest] -> {
      case dict.get(inner, tag) {
        Error(Nil) -> [first, ..add_in_list([second, ..rest], inner)]
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
            ..add_in_list([second, ..rest], inner)
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
        add_in_list(children |> list.reverse, inner) |> list.reverse,
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
  Ok(infra.triples_to_dict(param))
}

type Param =
  List(#(String,          String,           List(#(String, String))))
//       ↖              ↖                ↖
//       insert after   tag name         attributes
//       tag of this    of new element
//       name (except
//       if last child)

type InnerParam =
  Dict(String, #(String, List(#(String, String))))

/// adds new elements after specified tags but not if they are the last child
pub fn add_after_tags_but_not_first_child_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "add_after_tags_but_not_first_child_tags",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// adds new elements after specified tags but not if they are the last child
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}