import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/regexp.{type Regexp, type Match, Match}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe,
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

type State {
  State(
    handles: HandleInstances,
    local_path: Option(String),
  )
}

fn extract_handle_name(match) {
  let assert Match(_, [_, option.Some(handle_name)]) = match
  handle_name
}

fn hyperlink_constructor(
    handle: #(String, String, String),
    blame: Blame,
    state: State,
    inner: InnerParam,
) {
  let #(id, target_path, value) = handle
  let assert Some(local_path) = state.local_path
  let #(tag, classes) = case target_path == local_path {
    True -> #("InChapterLink", "handle-in-chapter-link")
    False -> #("a", "handle-out-of-chapter-link")
  }
  V(blame, tag, list.flatten([
      list.map(inner, fn(x) { BlamedAttribute(blame, x.0, x.1) }),
      [
        BlamedAttribute(blame, "href", target_path <> "?id=" <> id),
        BlamedAttribute(blame, "class", classes),
      ]
    ]),
    [T(blame, [BlamedContent(blame, value)])],
  )
}

fn hyperlink_maybe(
  handle_name: String,
  blame: Blame,
  state: State,
  inner: InnerParam,
) {
  case dict.get(state.handles, handle_name) {
    Ok(triple) -> Ok(hyperlink_constructor(triple, blame, state, inner))
    _ -> Error(DesugaringError(blame, "handle '" <> handle_name <> "' is not assigned"))
  }
}

fn matches_2_hyperlinks(
  matches: List(Match),
  blame: Blame,
  state: State,
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  matches
  |> list.map(extract_handle_name)
  |> list.map(hyperlink_maybe(_, blame, state, inner))
  |> result.all
}

fn augment_to_1_mod_3(
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

fn retain_0_mod_3(
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

fn split_2_t(
  split: String,
  blame: Blame,
) -> VXML {
  T(blame, [BlamedContent(blame, split)])
}

fn splits_2_text_nodes(
  splits: List(String),
  blame: Blame,
) -> List(VXML) {
  splits
  |> augment_to_1_mod_3  
  |> retain_0_mod_3
  |> list.map(split_2_t(_, blame))
}

fn process_blamed_content(
  blamed_content: BlamedContent,
  state: State,
  inner: InnerParam,
  handle_regexp: Regexp,
) -> Result(List(VXML), DesugaringError) {
  let BlamedContent(blame, content) = blamed_content
  let matches = regexp.scan(handle_regexp, content)
  let splits = regexp.split(handle_regexp, content)
  use hyperlinks <- result.try(matches_2_hyperlinks(matches, blame, state, inner))
  let text_nodes = splits_2_text_nodes(splits, blame)
  list.interleave([
    text_nodes,
    hyperlinks,
  ]) |> Ok
}

fn process_blamed_contents(
  contents: List(BlamedContent),
  state: State,
  inner: InnerParam,
  handle_regexp: Regexp,
) -> Result(List(VXML), DesugaringError) {
  contents
    |> list.map(process_blamed_content(_, state, inner, handle_regexp))
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
  state: State,
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(_, tag, attributes, _) = vxml
  case tag {
    _ if tag == "GrandWrapper" -> Ok(#(vxml, State(..state, handles: get_handles_instances_from_grand_wrapper(attributes))))
    _ if tag == "Chapter" || tag == "Bootcamp" -> {
      case infra.v_attribute_with_key(vxml, "path") {
        None -> Error(DesugaringError(vxml.blame, "'" <> tag <> "' node missing 'path' attribute"))
        Some(blamed_attribute) -> Ok(#(vxml, State(..state, local_path: Some(blamed_attribute.value))))
      }
    }
    _ -> Ok(#(vxml, state))
  }
}

fn v_after_transform(
  vxml: VXML,
  state: State,
) -> Result(#(List(VXML), State), DesugaringError) {
  let assert V(_, tag, _, children)  = vxml
  case tag == "GrandWrapper" {
    True -> {
      let assert [V(_, "Book", _, _) as root] = children
      Ok(#([root], state))
    }
    False -> Ok(#([vxml], state))
  }
}

fn t_transform(
  vxml: VXML,
  state: State,
  inner: InnerParam,
  handles_regexp: Regexp,
) -> Result(#(List(VXML), State), DesugaringError) {
  let assert T(_, contents)  = vxml
  use updated_contents <- result.try(process_blamed_contents(
    contents,
    state,
    inner,
    handles_regexp,
  ))
  Ok(#(updated_contents, state))
}

fn counter_handle_transform_factory(inner: InnerParam) -> infra.StatefulDownAndUpNodeToNodesTransform(
  State,
) {
  let assert Ok(handles_regexp) = regexp.from_string("(>>)(\\w+)")
  infra.StatefulDownAndUpNodeToNodesTransform(
    v_before_transforming_children: v_before_transform,
    v_after_transforming_children: fn(vxml, _, new) {v_after_transform(vxml, new)},
    t_transform: fn(vxml, state) { t_transform(vxml, state, inner, handles_regexp) },
  )
}

fn transform_factory(inner: InnerParam) -> infra.StatefulDownAndUpNodeToNodesTransform(
  State,
) {
  counter_handle_transform_factory(inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.stateful_down_up_node_to_nodes_desugarer_factory(
    transform_factory(inner),
    State(handles: dict.new(), local_path: None)
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

pub const desugarer_name = "handles_substitute"
pub const desugarer_pipe = handles_substitute

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
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
    desugarer_name,
    option.Some(ins(param)),
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
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}