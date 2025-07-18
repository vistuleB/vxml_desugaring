import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/regexp.{type Regexp, type Match, Match}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

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
  let #(
    _, _, 
    #(in_page_link_tag, in_page_link_classes),
    #(out_of_page_link_tag, out_of_page_link_classes)
  ) = inner

  let #(tag, classes) = case target_path == local_path {
    True -> #(in_page_link_tag, in_page_link_classes |> string.join(" "))
    False -> #(out_of_page_link_tag, out_of_page_link_classes |> string.join(" "))
  }

  V(
    blame,
    tag, 
    case classes {
      "" -> [
        BlamedAttribute(blame, "href", target_path <> "?id=" <> id),
      ]
      _ -> [
        BlamedAttribute(blame, "href", target_path <> "?id=" <> id),
        BlamedAttribute(blame, "class", classes),
      ]
    },
    [T(blame, [BlamedContent(blame, value)])],
  )
}

fn hyperlink_maybe(
  handle_name: String,
  blame: Blame,
  state: State,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
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
  inner: InnerParam
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(_, tag, attributes, _) = vxml
  let #(path_tags, path_key, _, _) = inner

  use <- infra.on_lazy_true_on_false(
    tag == "GrandWrapper",
    fn(){
      Ok(#(vxml, State(..state, handles: get_handles_instances_from_grand_wrapper(attributes))))
    }
  )

  use <- infra.on_lazy_true_on_false(
    list.contains(path_tags, tag),
    fn() {
      case infra.v_attribute_with_key(vxml, path_key) {
        None -> Error(DesugaringError(vxml.blame, "'" <> tag <> "' node missing '" <> path_key <> "' attribute"))
        Some(blamed_attribute) -> Ok(#(vxml, State(..state, local_path: Some(blamed_attribute.value))))
      }
    }
  )

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
  let assert Ok(handles_regexp) = regexp.from_string("(>>)(\\w+)")
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
  Ok(param)
}

type Param =
   #(
    List(String),            // tags that can have handle path value
    String,                  // handle path attribute key
    #(String, List(String)), // in-page link element tag / classes
    #(String, List(String)), // outer-page link element tag / classes
   )


type InnerParam = Param

const name = "handles_substitute"
const constructor = handles_substitute

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Expects a document with root 'GrandWrapper' 
/// whose attributes comprise of key-value pairs of
/// the form handle=handle_name | id | path | value
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
    "
/// Expects a document with root 'GrandWrapper' 
/// whose attributes comprise of key-value pairs of
/// the form handle=handle_name | id | path | value
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
                  ["Chapter", "Bootcamp"],
                  "path", #("InChapterLink",
                  ["handle-in-chapter-link"]),
                  #("a", ["handle-out-chapter-link"])
                ),
      source:   "
                <> GrandWrapper
                  handle=fluescence | _23-super-id | ./ch1.html | AA
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
                      href=./ch1.html?id=_23-super-id
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
                  ["Page"],
                  "testerpath",
                  #("inLink", []),
                  #("outLink", [])
                ),
      source:   "
                <> GrandWrapper
                  handle=fluescence | _23-super-id | ./ch1.html | AA
                  handle=out | _24-super-id | ./ch1.html | AA
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
                      href=./ch1.html?id=_23-super-id
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
                      href=./ch1.html?id=_24-super-id
                      <>
                        \"AA\"
                    <>
                      \" outer link\"
                ",
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}