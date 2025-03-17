import gleam/list
import gleam/string.{inspect as ins}
import gleam/option
import desugarers/remove_outside_subtrees.{remove_outside_subtrees}
import infrastructure.{ type Pipe, Pipe, DesugarerDescription }
import vxml_parser.{type VXML, V}

fn matches_a_key_value_pair(
  vxml: VXML,
  extra: Extra,
) -> Bool {
  let assert V(_, _, attrs, _) = vxml
  list.any(
    extra,
    fn (selector) {
      let #(key, value) = selector
      list.any(
        attrs,
        fn (attr) { attr.key == key && attr.value == value }
      )
    }
  )
}

type Extra =
  List(#(String, String))
//       ↖       ↖
//       key     value

/// filters by identifying nodes whose attributes
/// match at least one of the given #(key, value)
/// pairs. (OR not AND); keeps only nodes that
/// are descendants of such nodes, or ancestors
/// of such nodes
pub fn keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("keep_only_subtrees_and_ancestors_of_nodes_matching_a_key_value_pair", option.Some(extra |> ins), "filters by identifying nodes whose attributes
match at least one of the given #(key, value)
pairs. (OR not AND); keeps only nodes that
are descendants of such nodes, or ancestors
of such nodes"),
    desugarer: case extra {
      [] -> fn(vxml) { Ok(vxml) }
      _ -> remove_outside_subtrees(fn (vxml) { matches_a_key_value_pair(vxml, extra) }).desugarer
    }
  )
}
