import gleam/io
import gleam/pair
import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{
  type BlamedAttribute, type BlamedContent, type VXML, BlamedAttribute,
  BlamedContent, T, V,
}

type HandleInstances =
  Dict(String, #(String, String, String))

//   handle   local path, element id, string value
//   name     of page     on page     of handle

fn target_is_on_same_chapter(
  current_filename: String, // eg: /article/chapter1
  target_blame: Blame, // eg: chapter1/chapter.emu
) -> Bool {
  let assert [target_filename, ..] = target_blame.filename |> string.split("/")
  let assert [current_filename, ..] = current_filename |> string.split("/") |> list.reverse()

  target_filename == current_filename
}

fn construct_hyperlink(
  blame: Blame,
  handle: #(String, String, String),
  extra: Extra
) {
  let #(id, filename, value) = handle

  let tag = case target_is_on_same_chapter(filename, blame) {
    True -> "InChapterLink"
    False -> "a"
  }

  V(blame, tag, list.flatten([
      list.map(extra, fn(x) { BlamedAttribute(blame, pair.first(x), pair.second(x)) }),
      [BlamedAttribute(blame, "href", filename <> "#" <> id)]
    ]),
    [T(blame, [BlamedContent(blame, value)])])
}

fn handle_handle_matches(
  blame: Blame,
  matches: List(regexp.Match),
  splits: List(String),
  handles: HandleInstances,
  extra: Extra
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
            extra
          ))
          Ok(
            list.flatten([
              [T(blame, [BlamedContent(blame, first_split)])],
              [construct_hyperlink(blame, handle, extra)],
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
  extra: Extra

) -> Result(List(VXML), DesugaringError) {
  let assert Ok(re) = regexp.from_string("(>>)(\\w+)")

  let matches = regexp.scan(re, blamed_line.content)
  let splits = regexp.split(re, blamed_line.content)
  handle_handle_matches(blamed_line.blame, matches, splits, handles, extra)
}

fn print_handle_for_contents(
  contents: List(BlamedContent),
  handles: HandleInstances,
  extra: Extra
) -> Result(List(VXML), DesugaringError) {

  case contents {
    [] -> Ok([])
    [first, ..rest] -> {
      use updated_line <- result.try(print_handle(first, handles, extra))
      use updated_rest <- result.try(print_handle_for_contents(rest, handles, extra))

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
  extra: Extra
) -> Result(#(List(VXML), HandleInstances), DesugaringError) {
  case vxml {
    T(_, contents) -> {
      use update_contents <- result.try(print_handle_for_contents(
        contents,
        handles,
        extra
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

type Extra = List(#(String, String)) 
// list of additional key-value pair to attach to anchor tag

fn counter_handle_transform_factory(extra: Extra) -> infra.StatefulDownAndUpNodeToNodesTransform(
  HandleInstances,
) {
  infra.StatefulDownAndUpNodeToNodesTransform(
    before_transforming_children: fn(vxml, s) {
      use #(vxml, handles) <- result.try(
        counter_handles_transform_to_get_handles(vxml, s),
      )
      let assert [vxml] = vxml
      Ok(#(vxml, handles))
    },
    after_transforming_children: fn(vxml, _, new) {
      use #(vxml, handles) <- result.try(
        counter_handles_transform_to_replace_handles(vxml, new, extra),
      )
      Ok(#(vxml, handles))
    },
  )
}

fn desugarer_factory(extra) -> Desugarer {
  infra.stateful_down_up_node_to_nodes_desugarer_factory(
    counter_handle_transform_factory(extra),
    dict.new(),
  )
}

/// Looks for handle definitions in GrandWrapper and 
/// replaces >>handle occurences with defined value
/// Returns error if there's a handle occurence with no definition
/// # Extra
/// list of additional key-value pairs to attach to anchor tag
pub fn handles_substitute(extra: Extra) -> Pipe {

  Pipe(
    description: DesugarerDescription("handles_substitute", option.None, "
    Looks for handle definitions in GrandWrapper and replaces >>handle occurences with defined value \n
    Returns error if there's a handle occurence with no definition
    "),
    desugarer: desugarer_factory(extra),
  )
}
