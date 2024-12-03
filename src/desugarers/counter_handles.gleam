import gleam/list
import gleam/option
import gleam/regex
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, type StatefulDownAndUpNodeToNodeTransform,
  DesugarerDescription, DesugaringError, StatefulDownAndUpNodeToNodeTransform,
} as infra
import vxml_parser.{
  type Blame, type BlamedAttribute, type BlamedContent, type VXML, Blame,
  BlamedAttribute, BlamedContent, T, V,
}

type HandleInstance {
  HandleInstance(name: String, value: String)
}

fn handle_handle_matches(
  blame: Blame,
  matches: List(regex.Match),
  splits: List(String),
  handles: List(HandleInstance),
) -> Result(String, DesugaringError) {
  case matches {
    [] -> {
      Ok(string.join(splits, ""))
    }
    [first, ..rest] -> {
      let regex.Match(_, sub_matches) = first

      let assert [_, handle_name] = sub_matches
      let assert option.Some(handle_name) = handle_name
      case list.find(handles, fn(x) { x.name == handle_name }) {
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
          Ok(first_split <> handle.value <> rest_content)
        }
      }
    }
  }
}

fn print_handle(
  blamed_line: BlamedContent,
  handles: List(HandleInstance),
) -> Result(String, DesugaringError) {
  let assert Ok(re) = regex.from_string("(>>)(\\w+)")

  let matches = regex.scan(re, blamed_line.content)
  let splits = regex.split(re, blamed_line.content)
  handle_handle_matches(blamed_line.blame, matches, splits, handles)
}

fn print_handle_for_contents(
  contents: List(BlamedContent),
  handles: List(HandleInstance),
) -> Result(List(BlamedContent), DesugaringError) {
  case contents {
    [] -> Ok([])
    [first, ..rest] -> {
      use updated_line <- result.try(print_handle(first, handles))
      use updated_rest <- result.try(print_handle_for_contents(rest, handles))

      Ok([BlamedContent(first.blame, updated_line), ..updated_rest])
    }
  }
}

fn get_handles_from_root_attributes(
  attributes: List(BlamedAttribute),
) -> #(List(BlamedAttribute), List(HandleInstance)) {
  let handles =
    list.filter(attributes, fn(att) { string.starts_with(att.key, "handle_") })
    |> list.map(fn(att) {
      HandleInstance(string.drop_left(att.key, 7), att.value)
    })

  let filtered_attributes =
    list.filter(attributes, fn(att) {
      !{ string.starts_with(att.key, "handle_") }
    })
  #(filtered_attributes, handles)
}

fn counter_handles_transform_to_get_handles(
  vxml: VXML,
  handles: List(HandleInstance),
) -> Result(#(VXML, List(HandleInstance)), DesugaringError) {
  case vxml {
    V(b, t, attributes, c) -> {
      case t == "GrandWrapper" {
        False -> Ok(#(vxml, handles))
        True -> {
          let #(filtered_attributes, handles) =
            get_handles_from_root_attributes(attributes)

          Ok(#(V(b, t, filtered_attributes, c), handles))
        }
      }
    }
    _ -> Ok(#(vxml, handles))
  }
}

fn counter_handles_transform_to_replace_handles(
  vxml: VXML,
  handles: List(HandleInstance),
) -> Result(#(VXML, List(HandleInstance)), DesugaringError) {
  case vxml {
    T(b, contents) -> {
      use update_contents <- result.try(print_handle_for_contents(
        contents,
        handles,
      ))
      Ok(#(T(b, update_contents), handles))
    }
    V(_, t, _, children) -> {
      case t == "GrandWrapper" {
        False -> Ok(#(vxml, handles))
        True -> {
          let assert [first_child] = children
          Ok(#(first_child, handles))
        }
      }
    }
  }
}

fn counter_handle_transform_factory() -> StatefulDownAndUpNodeToNodeTransform(
  List(HandleInstance),
) {
  StatefulDownAndUpNodeToNodeTransform(
    before_transforming_children: fn(vxml, s) {
      counter_handles_transform_to_get_handles(vxml, s)
    },
    after_transforming_children: fn(vxml, _, new) {
      counter_handles_transform_to_replace_handles(vxml, new)
    },
  )
}

fn desugarer_factory() {
  infra.stateful_down_up_node_to_node_desugarer_factory(
    counter_handle_transform_factory(),
    [],
  )
}

pub fn counter_handles_desugarer() -> Pipe {
  #(
    DesugarerDescription("counter_handles", option.None, "..."),
    desugarer_factory(),
  )
}
