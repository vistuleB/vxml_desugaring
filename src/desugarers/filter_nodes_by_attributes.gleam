import gleam/io
import gleam/list
import gleam/string.{inspect as ins}
import gleam/pair
import gleam/option
import desugarers/remove_outside_subtrees.{remove_outside_subtrees}
import infrastructure.{type Pipe, DesugarerDescription}
import vxml_parser.{type VXML, V}

fn matches_a_key_value_pair(
  vxml: VXML,
  extra: Extra,
) -> Bool {
  let assert V(b, _, attrs, _) = vxml
  
  list.any(
    extra,
    fn (selector) {
      let #(path, key, value) = selector

      use <- infrastructure.on_true_on_false(
        !{string.contains(b.filename, path)},
        False
      )
   
      list.any(
        attrs,
        fn (attr) { {attr.key == key && attr.value == value} || key == "" }
      ) 
    }
  )
}

type Extra =
  List(#(String, String, String))
//         ↖        ↖       ↖
//         path      key     value

/// filters by identifying nodes whose attributes
/// match at least one of the given #(key, value)
/// pairs. (OR not AND); keeps only nodes that
/// are descendants of such nodes, or ancestors
/// of such nodes
pub fn filter_nodes_by_attributes(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "filter_nodes_by_attributes",
      option.Some(extra |> ins),
      "filters by identifying nodes whose attributes
match at least one of the given #(key, value)
pairs. (OR not AND); keeps only nodes that
are descendants of such nodes, or ancestors
of such nodes"
    ),
    case extra {
      [] -> fn(vxml) { Ok(vxml) }
      [#(_, "", "")] -> fn(vxml) { Ok(vxml) }
      _ -> {
         remove_outside_subtrees(matches_a_key_value_pair(_, extra)) |> pair.second }
    }
  )
}
