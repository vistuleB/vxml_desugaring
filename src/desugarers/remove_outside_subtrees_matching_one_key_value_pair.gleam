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

pub fn remove_outside_subtrees_matching_one_key_value_pair(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("remove_outside_subtrees_matching_one_key_value_pair", option.Some(extra |> ins), "..."),
    case extra {
      [] -> fn(vxml) { Ok(vxml) }
      _ -> remove_outside_subtrees(fn (vxml) { matches_a_key_value_pair(vxml, extra) }) |> pair.second
    }
  )
}
