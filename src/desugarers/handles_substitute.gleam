import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/regexp.{type Regexp, type Match, Match}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}
import blamedlines.{type Blame} as bl

type HandlesDict =
  Dict(String, #(String,   String,   String))
//     ↖         ↖         ↖         ↖
//     handle    value     id        path

type State {
  State(
    handles: HandlesDict,
    path: Option(String),
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
) -> Result(VXML, DesugaringError) {
  use path <- infra.on_lazy_none_on_some(
    state.path,
    fn(){Error(DesugaringError(blame, "handle occurrence when local path is not defined"))},
  )
  let #(value, id, target_path) = handle
  let #(tag, attrs) = case target_path == path {
    True -> #(inner.1, inner.3)
    False -> #(inner.2, inner.4)
  }
  let attrs = [
    BlamedAttribute(blame, "href", target_path <> "#" <> id),
    ..attrs
  ]
  Ok(V(
    blame,
    tag,
    attrs,
    [T(blame, [BlamedContent(blame, value)])],
  ))
}

fn hyperlink_maybe(
  handle_name: String,
  blame: Blame,
  state: State,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case dict.get(state.handles, handle_name) {
    Ok(triple) -> hyperlink_constructor(triple, blame, state, inner)
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

fn splits_2_ts(
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
  let text_nodes = splits_2_ts(splits, blame)
  Ok(list.interleave([text_nodes, hyperlinks]))
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
) -> HandlesDict {
  attributes
  |> list.fold(
    dict.new(),
    fn(acc, att) {
      let assert [handle_name, value, id, path] = att.value |> string.split("|")
      dict.insert(acc, handle_name, #(value, id, path))
    }
  )
}

fn update_handles(
  state: State,
  vxml: VXML,
) {
  let assert V(_, tag, attributes, _) = vxml
  case tag == "GrandWrapper" {
    True -> State(..state, handles: get_handles_instances_from_grand_wrapper(attributes))
    False -> state
  }
}

fn update_path(
  state: State,
  vxml: VXML,
  inner: InnerParam,
) -> State {
  let assert V(_, _, _, _) = vxml
  case infra.v_attribute_with_key(vxml, inner.0) {
    Some(BlamedAttribute(_, _, value)) -> State(..state, path: Some(value))
    None -> state
  }
}

fn v_before_transform(
  vxml: VXML,
  state: State,
  inner: InnerParam,
) -> Result(#(VXML, State), DesugaringError) {
  let state = state
    |> update_path(vxml, inner)
    |> update_handles(vxml)
  Ok(#(vxml, state))
}

fn v_after_transform(
  vxml: VXML,
  state: State,
) -> Result(#(List(VXML), State), DesugaringError) {
  let assert V(_, tag, _, children)  = vxml
  case tag == "GrandWrapper" {
    True -> {
      let assert [V(_, _, _, _) as root] = children
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

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyBeforeAndAfterStatefulNodeMap(State) {
  let assert Ok(handles_regexp) = regexp.from_string("(>>)([\\w\\^-]+)")
  n2t.OneToManyBeforeAndAfterStatefulNodeMap(
    v_before_transforming_children: fn(vxml, state) {v_before_transform(vxml, state, inner)},
    v_after_transforming_children: fn(vxml, _, new) {v_after_transform(vxml, new)},
    t_nodemap: fn(vxml, state) { t_transform(vxml, state, inner, handles_regexp) },
  )
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_many_before_and_after_stateful_nodemap_2_desufarer_transform(State(dict.new(), None))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  #(
    param.0,
    param.1,
    param.2,
    param.3 |> infra.string_pairs_2_blamed_attributes(desugarer_blame),
    param.4 |> infra.string_pairs_2_blamed_attributes(desugarer_blame),
  )
  |> Ok
}

type Param = #(String,            String,                 String,                List(#(String, String)),   List(#(String, String)))
//             ↖                  ↖                       ↖                      ↖                          ↖
//             attribute key      tag to use              tag to use             additional key-value       additional key-value
//             to update the      when handle path        when handle path       pairs for former case      pairs for latter case
//             local path         equals local path       !equals local path
//                                at point of insertion   at point of insertion
type InnerParam = #(String, String, String, List(BlamedAttribute), List(BlamedAttribute))

const name = "handles_substitute"
const constructor = handles_substitute
const desugarer_blame = bl.Des([], name)

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Expects a document with root 'GrandWrapper'
/// whose attributes comprise of key-value pairs of
/// the form handle=handle_name|value|id|path
/// and with a unique child being the root of the
/// original document.
///
/// Replaces >>handle_name occurrences by links,
/// using two different kinds of tags for links
/// that point to elements in the same page versus
/// links that point element in a different page.
///
/// More specifically, given an occurrence
/// >>handle_name where handle_name points to an
/// element of path 'path' as given by one of the
/// key-value pairs in GrandWrapper, determines if
/// 'path' is in another page of the final set of
/// pages with respect to the current page of the
/// document by trying to look up the latter on the
/// latest (closest) ancestor of the element whose
/// tag is an element of the first list in the
/// desugarer's Param argument, looking at the
/// attribute value of the attribute whose key is
/// the second argument of Param. The third and
/// fourth arguments of Param specify which tags
/// and classes to use for the in- and out- page
/// links respectively. If the class list is empty
/// no 'class' attribute will be added at all to
/// that type of link element.
///
/// Destroys the GrandWrapper root note on exit,
/// returning its unique child.
///
/// Throws a DesugaringError if a given handle name
/// is not found in the list of GrandWrapper
/// 'handle' attributes values, or if unable to
/// locate a local page path for a given handle.
pub fn handles_substitute(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// Expects a document with root 'GrandWrapper'
/// whose attributes comprise of key-value pairs of
/// the form handle=handle_name|value|id|path
/// and with a unique child being the root of the
/// original document.
///
/// Replaces >>handle_name occurrences by links,
/// using two different kinds of tags for links
/// that point to elements in the same page versus
/// links that point element in a different page.
///
/// More specifically, given an occurrence
/// >>handle_name where handle_name points to an
/// element of path 'path' as given by one of the
/// key-value pairs in GrandWrapper, determines if
/// 'path' is in another page of the final set of
/// pages with respect to the current page of the
/// document by trying to look up the latter on the
/// latest (closest) ancestor of the element whose
/// tag is an element of the first list in the
/// desugarer's Param argument, looking at the
/// attribute value of the attribute whose key is
/// the second argument of Param. The third and
/// fourth arguments of Param specify which tags
/// and classes to use for the in- and out- page
/// links respectively. If the class list is empty
/// no 'class' attribute will be added at all to
/// that type of link element.
///
/// Destroys the GrandWrapper root note on exit,
/// returning its unique child.
///
/// Throws a DesugaringError if a given handle name
/// is not found in the list of GrandWrapper
/// 'handle' attributes values, or if unable to
/// locate a local page path for a given handle.
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  [
    infra.AssertiveTestData(
      param:    #(
                  "path",
                  "InChapterLink",
                  "a",
                  [#("class", "handle-in-chapter-link")],
                  [#("class", "handle-out-chapter-link")],
                ),
      source:   "
                <> GrandWrapper
                  handle=fluescence|AA|_23-super-id|./ch1.html
                  <> root
                    <> Chapter
                      path=./ch1.html
                      <>
                        \"some text with >>fluescence in it\"
                      <> Math
                        <>
                          \"$x^2 + b^2$\"
                ",
      expected: "
                <> root
                  <> Chapter
                    path=./ch1.html
                    <>
                      \"some text with \"
                    <> InChapterLink
                      href=./ch1.html#_23-super-id
                      class=handle-in-chapter-link
                      <>
                        \"AA\"
                    <>
                      \" in it\"
                    <> Math
                      <>
                        \"$x^2 + b^2$\"
                ",
    ),
     infra.AssertiveTestData(
      param:    #(
                  "testerpath",
                  "inLink",
                  "outLink",
                  [#("class", "handle-in-link-class")],
                  [#("class", "handle-out-link-class")],
                ),
      source:   "
                <> GrandWrapper
                  handle=fluescence|AA|_23-super-id|./ch1.html
                  handle=out|AA|_24-super-id|./ch1.html
                  <> root
                    <> Page
                      testerpath=./ch1.html
                      <>
                        \"some text with >>fluescence in it\"
                      <> Math
                        <>
                          \"$x^2 + b^2$\"
                    <> Page
                      testerpath=./ch2.html
                      <>
                        \"this is >>out outer link\"
                ",
      expected: "
                <> root
                  <> Page
                    testerpath=./ch1.html
                    <>
                      \"some text with \"
                    <> inLink
                      href=./ch1.html#_23-super-id
                      class=handle-in-link-class
                      <>
                        \"AA\"
                    <>
                      \" in it\"
                    <> Math
                      <>
                        \"$x^2 + b^2$\"
                  <> Page
                    testerpath=./ch2.html
                    <>
                      \"this is \"
                    <> outLink
                      href=./ch1.html#_24-super-id
                      class=handle-out-link-class
                      <>
                        \"AA\"
                    <>
                      \" outer link\"
                ",
    ),
    infra.AssertiveTestData(
      param:    #(
                  "path",
                  "InChapterLink",
                  "a",
                  [#("class", "handle-in-chapter-link")],
                  [#("class", "handle-out-chapter-link")],
                ),
      source:   "
                <> GrandWrapper
                  handle=my-cardinal|Cardinal Number|_25-dash-id|./ch1.html
                  handle=test^handle|Caret Test|_26-caret-id|./ch1.html
                  <> root
                    <> Chapter
                      path=./ch1.html
                      <>
                        \"Reference to >>my-cardinal and >>test^handle here\"
                      <> Math
                        <>
                          \"$x^2 + b^2$\"
                ",
      expected: "
                <> root
                  <> Chapter
                    path=./ch1.html
                    <>
                      \"Reference to \"
                    <> InChapterLink
                      href=./ch1.html#_25-dash-id
                      class=handle-in-chapter-link
                      <>
                        \"Cardinal Number\"
                    <>
                      \" and \"
                    <> InChapterLink
                      href=./ch1.html#_26-caret-id
                      class=handle-in-chapter-link
                      <>
                        \"Caret Test\"
                    <>
                      \" here\"
                    <> Math
                      <>
                        \"$x^2 + b^2$\"
                ",
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
