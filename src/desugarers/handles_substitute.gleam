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
// we should be comparing the local_path of the handle
// to a 'path' attribute installed on the ancestor 
// chapter/bootcamp node of the handle occurrence;
// bcause the 'path' attribute of the blame relates 
// to the file structure of the source, that could 
// be out of sync with the file structure of the
// target (for example if we spotlight some chapters)
fn target_is_on_same_chapter(
  target_path: String, // eg: /article/chapter1
  current_blame: Blame, // eg: chapter1/chapter.emu
) -> Bool {
  let assert [current_blame_dir, ..] = current_blame.filename |> string.split("/")
  let assert [target_dir, ..] = target_path |> string.split("/") |> list.reverse()
  current_blame_dir == target_dir
}

fn matches_2_hyperlinks(
  matches: List(regexp.Match),
  blame: Blame,
  handles: HandleInstances,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  //************************//
  // functions for the pipe //
  //************************//
  // function 1
  let extract_name = fn(match) {
    let assert regexp.Match(_, [_, option.Some(handle_name)]) = match
    handle_name
  }

  // function 2
  let handle_2_hyperlink = fn(
    handle: #(String, String, String),
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

  // function 3
  let hyperlink_maybe = fn(handle_name) {
    case dict.get(handles, handle_name) {
      Ok(triple) -> Ok(handle_2_hyperlink(triple))
      _ -> Error(DesugaringError(blame, "handle '" <> handle_name <> "' is not assigned"))
    }
  }

  //************************//
  // the pipe               //
  //************************//
  matches
  |> list.map(extract_name)
  |> list.map(hyperlink_maybe)
  |> result.all
}

fn splits_2_text_nodes(
  splits: List(String),
  blame: Blame,
) -> List(VXML) {
  //************************//
  // functions for the pipe //
  //************************//
  // function 1
  let augment_to_1_mod_3 = fn(
    splits: List(String),
  ) -> List(String) {
    case list.length(splits) % 3 != 1 {
      True -> {
        let assert True = list.is_empty(splits)
        [""]
      }
      False -> splits
    }
  }

  // function 2
  let retain_0_mod_3 = fn(
    splits: List(String),
  ) -> List(String) {
    splits
    |> list.index_fold(
      from: [],
      with: fn(acc, split, index) {
        case index % 3 == 0 {
          True -> [split, ..acc]
          False -> acc
        }
      }
    )
    |> list.reverse
  }

  // function 3
  let split_2_t = fn(
    split: String,
  ) -> VXML {
    T(blame, [BlamedContent(blame, split)])
  }

  //************************//
  // the pipe               //
  //************************//
  splits
  |> augment_to_1_mod_3  
  |> retain_0_mod_3
  |> list.map(split_2_t)
}

fn handles_2_hyperlinks_in_content(
  blamed_content: BlamedContent,
  handles: HandleInstances,
  inner: InnerParam,
  handle_regexp: Regexp,
) -> Result(List(VXML), DesugaringError) {
  let BlamedContent(blame, content) = blamed_content
  let matches = regexp.scan(handle_regexp, content)
  let splits = regexp.split(handle_regexp, content)
  use hyperlinks <- result.then(matches_2_hyperlinks(matches, blame, handles, inner))
  let text_nodes = splits_2_text_nodes(splits, blame)
  list.interleave([
    text_nodes,
    hyperlinks,
  ]) |> Ok
}

fn print_handle_for_contents(
  contents: List(BlamedContent),
  handles: HandleInstances,
  inner: InnerParam,
  handle_regexp: Regexp,
) -> Result(List(VXML), DesugaringError) {
  contents
    |> list.map(handles_2_hyperlinks_in_content(_, handles, inner, handle_regexp))
    |> result.all
    |> result.map(list.flatten)                      // you now have a list of t-nodes and of hyperlinks
    |> result.map(infra.plain_concatenation_in_list) // adjacent t-nodes are wrapped into single t-node, with 1 blamed_content per old t-node (pre-concatenation)
}

fn get_handles_instances_from_grand_wrapper(
  attributes: List(BlamedAttribute),
) -> HandleInstances {
  attributes
  |> list.fold(
    dict.new(),
    fn(acc, att) {
      let assert [handle_name, id, filename, value] = att.value |> string.split(" | ")
      dict.insert(acc, handle_name, #(id, filename, value))
    }
  )
}

fn v_before_transform(
  vxml: VXML,
  handles: HandleInstances,
) -> Result(#(VXML, HandleInstances), DesugaringError) {
  let assert V(_, tag, attributes, _) = vxml
  case tag == "GrandWrapper" {
    True -> Ok(#(vxml, get_handles_instances_from_grand_wrapper(attributes)))
    False -> Ok(#(vxml, handles))
  }
}

fn v_after_transform(
  vxml: VXML,
  handles: HandleInstances,
) -> Result(#(List(VXML), HandleInstances), DesugaringError) {
  let assert V(_, tag, _, children)  = vxml
  case tag == "GrandWrapper" {
    True -> {
      let assert [V(_, "Book", _, _) as root] = children
      Ok(#([root], handles))
    }
    False -> Ok(#([vxml], handles))
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