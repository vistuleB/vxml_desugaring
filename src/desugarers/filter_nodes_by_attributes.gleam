import desugarers/remove_outside_subtrees.{remove_outside_subtrees}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Pipe, DesugarerDescription, Pipe}
import vxml.{type VXML, V}

fn matches_a_selector(vxml: VXML, extra: Extra) -> Bool {
  let assert V(b, _, attrs, _) = vxml
  list.any(extra, fn(selector) {
    let #(path, key, value) = selector
    {
      string.contains(b.filename, path)
      && {
        key == ""
        || list.any(attrs, fn(attr) {
          { attr.key == key && attr.value == value }
        })
      }
    }
  })
}

type Extra =
  List(#(String, String, String))

//         ↖        ↖       ↖
//         path     key     value

/// filters by identifying nodes whose
/// blame.filename contain the extra.path
/// as a substring and whose attributes
/// match at least one of the given #(key, value)
/// pairs, with a match counting as true
/// if key == ""; keeps only nodes that
/// are descendants of such nodes, or
/// ancestors of such nodes
pub fn filter_nodes_by_attributes(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "filter_nodes_by_attributes",
      option.Some(extra |> ins),
      "filters by identifying nodes whose
blame.filename contain the extra.path
as a substring and whose attributes
match at least one of the given #(key, value)
pairs, with a match counting as true
if key == \"\"; keeps only nodes that
are descendants of such nodes, or
ancestors of such nodes",
    ),
    desugarer: case extra {
      [] -> fn(vxml) { Ok(vxml) }
      _ -> remove_outside_subtrees(matches_a_selector(_, extra)).desugarer
    },
  )
}
