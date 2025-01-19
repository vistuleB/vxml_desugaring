import blamedlines.{type Blame}
import desugarers/counter_handles_dict_factory.{type HandleInstances}
import gleam/dict
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, type StatefulDownAndUpNodeToNodesTransform,
  DesugarerDescription, DesugaringError, StatefulDownAndUpNodeToNodesTransform,
} as infra
import vxml_parser.{
  type BlamedAttribute, type BlamedContent, type VXML, BlamedAttribute,
  BlamedContent, T, V,
}

fn construct_hyperlink(blame: Blame, handle: #(String, String, String)) {
  let #(id, filename, value) = handle
  V(blame, "a", [BlamedAttribute(blame, "href", "/" <> filename <> "#" <> id)], [
    T(blame, [BlamedContent(blame, value)]),
  ])
}

fn handle_handle_matches(
  blame: Blame,
  matches: List(regexp.Match),
  splits: List(String),
  handles: HandleInstances,
  //         
  //
  //
  //
) -> Result(List(VXML), DesugaringError) {
  case matches {
    [] -> {
      Ok([T(blame, [BlamedContent(blame, string.join(splits, " "))])])
    }
    [first, ..rest] -> {
      let regexp.Match(_, sub_matches) = first

      let assert [_, handle_name] = sub_matches
      let assert option.Some(handle_name) = handle_name
      case dict.get(handles, handle_name) {
        Error(_) ->
          Error(DesugaringError(
            blame,
            "Handle " <> handle_name <> " was not assigned",
          ))
        Ok(handle) -> {
          let assert [first_split, _, _, ..rest_splits] = splits
          use rest_content <- result.try(handle_handle_matches(
            blame,
            rest,
            rest_splits,
            handles,
          ))
          Ok(
            list.flatten([
              [T(blame, [BlamedContent(blame, first_split)])],
              [construct_hyperlink(blame, handle)],
              rest_content,
            ]),
          )
        }
      }
    }
  }
}

fn print_handle(
  blamed_line: BlamedContent,
  handles: HandleInstances,
) -> Result(List(VXML), DesugaringError) {
  let assert Ok(re) = regexp.from_string("(>>)(\\w+)")

  let matches = regexp.scan(re, blamed_line.content)
  let splits = regexp.split(re, blamed_line.content)
  handle_handle_matches(blamed_line.blame, matches, splits, handles)
}

fn print_handle_for_contents(
  contents: List(BlamedContent),
  handles: HandleInstances,
) -> Result(List(VXML), DesugaringError) {
  case contents {
    [] -> Ok([])
    [first, ..rest] -> {
      use updated_line <- result.try(print_handle(first, handles))
      use updated_rest <- result.try(print_handle_for_contents(rest, handles))

      Ok(list.flatten([updated_line, updated_rest]))
    }
  }
}

fn get_handles_from_root_attributes(
  attributes: List(BlamedAttribute),
) -> #(List(BlamedAttribute), HandleInstances) {
  let handles =
    list.filter(attributes, fn(att) { string.starts_with(att.key, "handle_") })
    |> list.fold(dict.new(), fn(acc, att) {
      let handle_name = string.drop_start(att.key, 7)
      let assert [id, filename, value] = att.value |> string.split(" | ")
      dict.insert(acc, handle_name, #(id, filename, value))
    })

  let filtered_attributes =
    list.filter(attributes, fn(att) {
      !{ string.starts_with(att.key, "handle_") }
    })
  #(filtered_attributes, handles)
}

fn counter_handles_transform_to_get_handles(
  vxml: VXML,
  handles: HandleInstances,
) -> Result(#(List(VXML), HandleInstances), DesugaringError) {
  case vxml {
    V(b, t, attributes, c) -> {
      case t == "GrandWrapper" {
        False -> Ok(#([vxml], handles))
        True -> {
          let #(filtered_attributes, handles) =
            get_handles_from_root_attributes(attributes)

          Ok(#([V(b, t, filtered_attributes, c)], handles))
        }
      }
    }
    _ -> Ok(#([vxml], handles))
  }
}

fn counter_handles_transform_to_replace_handles(
  vxml: VXML,
  handles: HandleInstances,
) -> Result(#(List(VXML), HandleInstances), DesugaringError) {
  case vxml {
    T(b, contents) -> {
      use update_contents <- result.try(print_handle_for_contents(
        contents,
        handles,
      ))
      Ok(#(update_contents, handles))
    }
    V(_, t, _, children) -> {
      case t == "GrandWrapper" {
        False -> Ok(#([vxml], handles))
        True -> {
          let assert [first_child] = children
          Ok(#([first_child], handles))
        }
      }
    }
  }
}

fn counter_handle_transform_factory() -> StatefulDownAndUpNodeToNodesTransform(
  HandleInstances,
) {
  StatefulDownAndUpNodeToNodesTransform(
    before_transforming_children: fn(vxml, s) {
      use #(vxml, handles) <- result.try(
        counter_handles_transform_to_get_handles(vxml, s),
      )
      let assert [vxml] = vxml
      Ok(#(vxml, handles))
    },
    after_transforming_children: fn(vxml, _, new) {
      use #(vxml, handles) <- result.try(
        counter_handles_transform_to_replace_handles(vxml, new),
      )
      Ok(#(vxml, handles))
    },
  )
}

fn desugarer_factory() {
  infra.stateful_down_up_node_to_nodes_desugarer_factory(
    counter_handle_transform_factory(),
    dict.new(),
  )
}

pub fn counter_handles_desugarer() -> Pipe {
  #(
    DesugarerDescription("counter_handles", option.None, "..."),
    desugarer_factory(),
  )
}
