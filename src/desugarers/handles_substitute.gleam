import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/regexp.{type Regexp}
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
  Dict(String, #(String,     String,     String))
//     ↖         ↖           ↖           ↖
//     handle    local path  element id  string value
//     name      of page     on page     of handle

// this seems very fragile & basically incorrect;
// we should be comparing a 'path' attribute installed
// on the chapter/bootcamp node to the local_path
// of the handle; the 'path' attribute 
fn target_is_on_same_chapter(
  target_path: String, // eg: /article/chapter1
  current_blame: Blame, // eg: chapter1/chapter.emu
) -> Bool {
  let assert [current_blame_dir, ..] = current_blame.filename |> string.split("/")
  let assert [target_dir, ..] = target_path |> string.split("/") |> list.reverse()
  current_blame_dir == target_dir
}

fn construct_hyperlink(
  blame: Blame,
  handle: #(String, String, String),
  inner: InnerParam,
) {
  let #(id, filename, value) = handle
  let #(tag, classes) = case target_is_on_same_chapter(filename, blame) {
    True -> #("InChapterLink", "handle-in-chapter-link")
    False -> #("a", "handle-out-of-chapter-link")
  }
  V(blame, tag, list.flatten([
      list.map(inner, fn(x) { BlamedAttribute(blame, x.0, x.1) }),
      [
        BlamedAttribute(blame, "href", filename <> "?id=" <> id),
        BlamedAttribute(blame, "class", classes),
      ]
    ]),
    [T(blame, [BlamedContent(blame, value)])],
  )
}

fn handle_handle_matches(
  blame: Blame,
  matches: List(regexp.Match),
  splits: List(String),
  handles: HandleInstances,
  inner: InnerParam
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
            "handle '" <> handle_name <> "' is not assigned",
          ))

        Ok(handle) -> {
          let assert [first_split, _, _, ..rest_splits] = splits

          use rest_content <- result.then(handle_handle_matches(
            blame,
            rest,
            rest_splits,
            handles,
            inner
          ))

          Ok(
            [
              T(blame, [BlamedContent(blame, first_split)]),
              construct_hyperlink(blame, handle, inner),
              ..rest_content,
            ],
          )
        }
      }
    }
  }
}

fn print_handle(
  blamed_line: BlamedContent,
  handles: HandleInstances,
  inner: InnerParam,
  handle_regexp: Regexp,
) -> Result(List(VXML), DesugaringError) {
  let matches = regexp.scan(handle_regexp, blamed_line.content)
  let splits = regexp.split(handle_regexp, blamed_line.content)
  handle_handle_matches(blamed_line.blame, matches, splits, handles, inner)
}

fn print_handle_for_contents(
  contents: List(BlamedContent),
  handles: HandleInstances,
  inner: InnerParam,
  handle_regexp: Regexp,
) -> Result(List(VXML), DesugaringError) {
  case contents {
    [] -> Ok([])
    [first, ..rest] -> {
      use updated_line <- result.then(print_handle(first, handles, inner, handle_regexp))
      use updated_rest <- result.then(print_handle_for_contents(rest, handles, inner, handle_regexp))
      Ok(
        list.flatten([updated_line, updated_rest])
        |> infra.plain_concatenation_in_list
      )
    }
  }
}

fn get_handles_from_root_attributes(
  attributes: List(BlamedAttribute),
) -> #(List(BlamedAttribute), HandleInstances) {

   let #(handle_attributes, filtered_attributes) =
    list.partition(attributes, fn(att) {
      att.key == "handle"
    })

  let extracted_handles =
    handle_attributes
    |> list.fold(dict.new(), fn(acc, att) {
      let assert [handle_name, id, filename, value] = att.value |> string.split(" | ")
      dict.insert(acc, handle_name, #(id, filename, value))
    })

  #(filtered_attributes, extracted_handles)
}

fn v_before_transform(
  vxml: VXML,
  handles: HandleInstances,
) -> Result(#(VXML, HandleInstances), DesugaringError) {
  let assert V(b, t, attributes, c) = vxml
  case t == "GrandWrapper" {
    False -> Ok(#(vxml, handles))
    True -> {
      let #(filtered_attributes, handles) =
        get_handles_from_root_attributes(attributes)

      Ok(#(V(b, t, filtered_attributes, c), handles))
    }
  }
}

fn v_after_transform(
  vxml: VXML,
  handles: HandleInstances
) -> Result(#(List(VXML), HandleInstances), DesugaringError) {
  let assert V(_, t, _, children)  = vxml
  case t == "GrandWrapper" {
    False -> Ok(#([vxml], handles))
    True -> {
      let assert [first_child] = children
      Ok(#([first_child], handles))
    }
  }
}

fn t_transform(
  vxml: VXML,
  handles: HandleInstances,
  inner: InnerParam,
  handles_regexp: Regexp,
) -> Result(#(List(VXML), HandleInstances), DesugaringError) {
  let assert T(_, contents)  = vxml
  use updated_contents <- result.then(print_handle_for_contents(
    contents,
    handles,
    inner,
    handles_regexp,
  ))
  Ok(#(updated_contents, handles))
}

fn counter_handle_transform_factory(inner: InnerParam) -> infra.StatefulDownAndUpNodeToNodesTransform(
  HandleInstances,
) {
  let assert Ok(handles_regexp) = regexp.from_string("(>>)(\\w+)")
  infra.StatefulDownAndUpNodeToNodesTransform(
    v_before_transforming_children: v_before_transform,
    v_after_transforming_children: fn(vxml, _, new) {v_after_transform(vxml, new)},
    t_transform: fn(vxml, state) { t_transform(vxml, state, inner, handles_regexp) },
  )
}

fn transform_factory(inner: InnerParam) -> infra.StatefulDownAndUpNodeToNodesTransform(
  HandleInstances,
) {
  counter_handle_transform_factory(inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.stateful_down_up_node_to_nodes_desugarer_factory(
    transform_factory(inner),
    dict.new(),
  )
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))
//       ↖       ↖
//       additional key-value pairs
//       to attach to anchor tag

type InnerParam = Param

//------------------------------------------------53
/// Expects a document with root 'GrandWrapper' 
/// whose attributes comprise of key-value pairs of
/// the form : handle_name | id | filename | value
/// and with a unique child being the  root of the 
/// original document.
/// 
/// Traverses the document and replaces each 
/// >>handle_name occurrence by...
/// ```
/// <InChapterLink href='filename?id=id'>
///   handle_value
/// </InChapterLink>
/// ```
/// ...if the filename is the same as the current 
/// document's filename, or...
/// ```
/// <a href='filename?id=id'>
///  handle_value
/// </a>
/// ```
/// ...elsewise.
/// 
/// Destroys the GrandWrapper on exit, returning its
/// unique child. 
/// 
/// Throws a DesugaringError if handle_name in
/// >>handle_name doesn't exist in the GrandWrapper 
/// attributes.
pub fn handles_substitute(param: Param) -> Pipe {

  Pipe(
    description: DesugarerDescription(
      "handles_substitute",
      option.None,
      "
/// Expects a document with root 'GrandWrapper' 
/// whose attributes comprise of key-value pairs of
/// the form : handle_name | id | filename | value
/// and with a unique child being the  root of the 
/// original document.
/// 
/// Traverses the document and replaces each 
/// >>handle_name occurrence by...
/// ```
/// <InChapterLink href='filename?id=id'>
///   handle_value
/// </InChapterLink>
/// ```
/// ...if the filename is the same as the current 
/// document's filename, or...
/// ```
/// <a href='filename?id=id'>
///  handle_value
/// </a>
/// ```
/// ...elsewise.
/// 
/// Destroys the GrandWrapper on exit, returning its
/// unique child. 
/// 
/// Throws a DesugaringError if handle_name in
/// >>handle_name doesn't exist in the GrandWrapper 
/// attributes.
      "
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}