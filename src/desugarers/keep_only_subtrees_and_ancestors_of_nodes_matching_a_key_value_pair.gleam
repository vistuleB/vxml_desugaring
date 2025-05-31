import desugarers/remove_outside_subtrees.{remove_outside_subtrees}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Pipe, DesugarerDescription, Pipe}
import vxml.{type VXML, V}

fn matches_a_key_value_pair(vxml: VXML, param: InnerParam) -> Bool {
  let assert V(_, _, attrs, _) = vxml
  list.any(param, fn(selector) {
    let #(key, value) = selector
    list.any(attrs, fn(attr) { attr.key == key && attr.value == value })
  })
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))

//       ↖       ↖
//       key     value

type InnerParam = Param

/// filters by identifying nodes whose attributes
/// match at least one of the given #(key, value)
/// pairs. (OR not AND); keeps only nodes that
/// are descendants of such nodes, or ancestors
/// of such nodes
pub fn keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair(
  param: Param,
) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair",
      option.Some(param |> ins),
      "filters by identifying nodes whose attributes
match at least one of the given #(key, value)
pairs. (OR not AND); keeps only nodes that
are descendants of such nodes, or ancestors
of such nodes",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> case inner_param {
        [] -> fn(vxml) { Ok(vxml) }
        _ ->
          remove_outside_subtrees(fn(vxml) {
            matches_a_key_value_pair(vxml, inner_param)
          }).desugarer
      }
    }
  )
}
