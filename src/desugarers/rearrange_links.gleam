import gleam/io
import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/regexp
import gleam/result
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{
  type BlamedAttribute, type VXML, BlamedAttribute, BlamedContent, T, V,
}
import xmlm
 
const ins = string.inspect
 
type LinkPatternToken {
  Word(String)    // (does not contain whitespace)
  Space
  Variable(Int)
  A(
    String,       // tag name ( for now it's either a or InChapterLink )
    String,       // classes
    Int,          // href variable
    LinkPattern,  // the List(LinkPatternToken) inside of the a-tag
  )
}
 
type LinkPattern =
  List(LinkPatternToken)
 
type InfoDict =
  Dict(
    Int,  // integer reference of href
    #(
      String,
      String,
      List(
        String,
        // the href link variable ( respresenting the Int  In LinkPatternToken A(String, Int, LinkPattern)  )
        // matched tag name ( for now either a or InChapterLink )
        // the original href value
      ),
      // the original text __OneWord "val" payload matched by the `_1_`
    ),
  )
 
type MatchingAccumulator =
  #(
    Bool, // whether the pattern has been matched
    Int,  // number of matched tokens in source pattern
    Int,  // index of the first element matched
    Int,  // index of the last element matched
    InfoDict,
  )
 
fn word_to_node(blame: Blame, word: String) {
  V(
    blame,
    "__OneWord",
    [BlamedAttribute(infra.blame_us("..."), "val", word)],
    [],
  )
}
 
fn space_node(blame: Blame) {
  V(blame, "__OneSpace", [], [])
}
 
fn line_node(blame: Blame) {
  V(blame, "__OneNewLine", [], [])
}
 
fn end_node(blame: Blame) {
  V(blame, "__EndAtomizedT", [], [])
}
 
fn deatomize_vxmls(
  children: List(VXML),
  accumulated_contents: List(vxml.BlamedContent),
) -> #(List(VXML), List(vxml.BlamedContent)) {
  case children {
    [] -> #([], [])
    [first, ..rest] -> {
      let #(nodes, accumulated_contents) = case first {
        V(blame, "__OneWord", attributes, _) -> {
          let assert [BlamedAttribute(_, "val", word)] = attributes
          let last_line = case list.last(accumulated_contents) {
            Ok(last_line) -> last_line
            Error(_) -> BlamedContent(blame, "")
          }
          let last_line =
            BlamedContent(..last_line, content: last_line.content <> word)
          let accumulated_contents =
            accumulated_contents
            |> list.length
            |> int.add(-1)
            |> list.take(accumulated_contents, _)
            |> list.append([last_line])
 
          #([], accumulated_contents)
        }
        V(blame, "__OneSpace", _, _) -> {
          let last_line = case list.last(accumulated_contents) {
            Ok(last_line) -> last_line
            Error(_) -> BlamedContent(blame, "")
          }
          let last_line =
            BlamedContent(..last_line, content: last_line.content <> " ")
          let accumulated_contents =
            accumulated_contents
            |> list.length
            |> int.add(-1)
            |> list.take(accumulated_contents, _)
            |> list.append([last_line])
 
          #([], accumulated_contents)
        }
        V(blame, "__OneNewLine", _, _) -> {
          let accumulated_contents =
            accumulated_contents
            |> list.append([BlamedContent(blame, "")])
 
          #([], accumulated_contents)
        }
        V(blame, "__EndAtomizedT", _, _) -> {
          #([T(blame, accumulated_contents)], [])
        }
        V(b, "a", a, children) | V(b, "InChapterLink", a, children) -> {
          let V(_, ze_tag, _, _) = first
          let updated_children = deatomize_vxmls(children, []) |> pair.first
          // check if next is a new line to add a space
          let accumulated_contents = case rest {
            [] -> []
            [next, ..] -> {
              case next {
                V(_, "__OneNewLine", _, _) -> {
                  [BlamedContent(b, " ")]
                }
                _ -> []
              }
            }
          }
 
          #([V(b, ze_tag, a, updated_children)], accumulated_contents)
        }
        V(_, _, _, _) -> {
          #([first], [])
        }
        _ -> #([], []) // should never happen
      }
      let #(rest_nodes, _) = deatomize_vxmls(rest, accumulated_contents)
      #(list.flatten([nodes, rest_nodes]), [])
    }
  }
}
 
fn get_list_of_variables(info_dict: InfoDict) -> List(String) {
  info_dict
  |> dict.map_values(fn(_, value) { value |> infra.triples_third })
  |> dict.values
  |> list.flatten
}
 
fn add_end_node_indicator(next_index: Int, pattern: LinkPattern) -> List(VXML) {
  let next_token = pattern |> infra.get_at(next_index)
  case next_token {
    Ok(A(_, _, _, _)) | Error(_) -> {
      [end_node(infra.blame_us("..."))]
    }
    _ -> []
  }
}
 
fn replace(
  blame: Blame,
  info_dict: InfoDict,
  pattern2: LinkPattern,
) -> Result(List(VXML), DesugaringError) {
  pattern2
  |> list.index_map(
    fn(token, i) {
      case token {
        Word(word) -> {
          list.flatten([
            [word_to_node(blame, word)],
            add_end_node_indicator(i + 1, pattern2),
          ])
          |> Ok
        }
        Space -> {
          list.flatten([
            [space_node(blame)],
            add_end_node_indicator(i + 1, pattern2),
          ])
          |> Ok
        }
        Variable(var) -> {
          let assert Ok(var_value) = info_dict |> get_list_of_variables |> infra.get_at(var - 1)
          list.flatten([
            [word_to_node(blame, var_value)],
            add_end_node_indicator(i + 1, pattern2),
          ])
          |> Ok
        }
        A(_, classes, var, sub_pattern) -> {
          use link_info <- result.try(
            info_dict
            |> dict.get(var)
            |> result.map_error(fn(_) {DesugaringError(blame, "Href " <> ins(var) <> " was not found")}),
          )
          let tag = link_info |> infra.triples_first
          let href_value = link_info |> infra.triples_second
          use a_node_children <- result.try(replace(
            blame,
            info_dict,
            sub_pattern,
          ))
          let new_a_node =
            V(
              blame,
              tag,
              [
                BlamedAttribute(blame, "href", href_value),
                BlamedAttribute(blame, "class", classes),
              ],
              a_node_children,
            )
          [new_a_node] |> Ok
        }
      }
    }
  )
  |> result.all
  |> result.map(list.flatten)
}
 
fn check_pattern_is_completed(
  acc: MatchingAccumulator,
  pattern: LinkPattern,
) -> MatchingAccumulator {
  let #(is_match, last_found_index, start, end, dict) = acc
  // extra check to see if the pattern is fully completed
  case is_match && last_found_index < list.length(pattern) {
    True -> {
      #(False, last_found_index, start, end, dict)
    }
    _ -> acc
  }
}
 
fn match_word(
  acc: MatchingAccumulator,
  attrs: List(BlamedAttribute),
  token: LinkPatternToken,
  global_index: Int,
) -> MatchingAccumulator {
  let assert [BlamedAttribute(_, "val", word)] = attrs
  let #(prev_is_match, last_found_index, start, _, prev_dict) = acc
 
  let #(is_match, original_word) = case token {
    Word(w) -> #(w == word, w)
    Variable(_) -> {
      #(True, word)
    }
    _ -> #(False, "")
  }
 
  let last_found_index = case is_match {
    True -> last_found_index + 1
    False -> 0
  }
 
  let start = update_start_index(start, global_index, is_match, prev_is_match)
  #(
    is_match,
    last_found_index,
    start,
    global_index,
    dict.insert(
      prev_dict,
      global_index * -1,
      #("will_be_trashed", "", [original_word]),
    ),
  )
}
 
fn match_space_or_line(
  next_child: Result(VXML, Nil),
  acc: MatchingAccumulator,
  token: LinkPatternToken,
  global_index: Int,
) -> MatchingAccumulator {
  let #(prev_is_match, last_found_index, start, _, prev_dict) = acc
  let start = update_start_index(start, global_index, True, prev_is_match)
 
  let new_last_found_index = case next_child {
    Ok(V(_, "__OneSpace", _, _)) | Ok(V(_, "__OneNewLine", _, _)) -> {
      last_found_index
    }
    _ -> last_found_index + 1
  }
  case token {
    Space -> #(
      True,
      new_last_found_index,
      start,
      global_index,
      dict.insert(prev_dict, global_index * -1, #("will_be_trashed", "", [""])),
    )
    _ -> #(False, 0, start, global_index, dict.new())
  }
}
 
fn match_a(
  acc: MatchingAccumulator,
  child: VXML,
  token: LinkPatternToken,
  global_index: Int,
) -> MatchingAccumulator {
  let #(prev_is_match, last_found_index, start, _, prev_dict) = acc
  let assert V(_, tag, attrs, sub_children) = child
 
  case token {
    A(_, _, val, sub_pattern) -> {
      let #(is_match, _, _, _, new_dict) =
        match(sub_children, 0, global_index, sub_pattern)
 
      let assert Ok(BlamedAttribute(_, _, href_value)) =
        list.find(attrs, fn(x) {
          case x {
            BlamedAttribute(_, "href", _) -> True
            _ -> False
          }
        })
 
      let words =
        new_dict
        |> dict.map_values(fn(_, value) { value |> infra.triples_third })
        |> dict.values
        |> list.flatten
 
      let new_dict =
        dict.new()
        |> dict.insert(val, #(tag, href_value, words))
 
      let last_found_index = case is_match {
        True -> last_found_index + 1
        False -> 0
      }
 
      let start =
        update_start_index(start, global_index, is_match, prev_is_match)
 
      #(
        is_match,
        last_found_index,
        start,
        global_index,
        dict.merge(prev_dict, new_dict),
      )
    }
    _ -> #(False, 0, start, global_index, dict.new())
  }
}

fn update_start_index(
  start_index: Int,
  global_index: Int,
  is_match: Bool,
  prev_is_match: Bool,
) -> Int {
  case is_match, prev_is_match {
    True, True -> start_index
    _, _ -> global_index
  }
}
 
fn match(
  atomized_children: List(VXML),
  where_to_start: Int, // which child to use as starting point
  global_index: Int,
  pattern: LinkPattern,
) -> MatchingAccumulator {
  let init_acc = #(False, 0, 0, 0, dict.new())
 
  atomized_children
  |> list.drop(where_to_start)
  |> list.index_fold(init_acc, fn(acc, child, index) {
    let #(_, last_found_index, start, end, prev_dict) = acc
    let global_index = index + global_index
    let next_child = infra.get_at(atomized_children, where_to_start + index + 1)
    case pattern |> list.drop(last_found_index) {
      [] -> {
        #(True, last_found_index, start, end, prev_dict)
      }
      [head_token, ..] -> {
        case child {
          V(_, "__OneWord", attrs, _) ->
            match_word(acc, attrs, head_token, global_index)
          V(_, "__OneSpace", _, _) | V(_, "__OneNewLine", _, _) ->
            match_space_or_line(next_child, acc, head_token, global_index)
          V(_, "a", _, _) -> match_a(acc, child, head_token, global_index)
          V(_, "InChapterLink", _, _) ->
            match_a(acc, child, head_token, global_index)
          _ -> acc
        }
      }
    }
  })
  |> check_pattern_is_completed(pattern)
}
 
fn match_until_end(
  atomized_children: List(VXML),
  pattern1: LinkPattern,
  pattern2: LinkPattern,
  where_to_start: Int,
) -> Result(List(VXML), DesugaringError) {
 
  let #(match, _, start, end, info_dict) = match(atomized_children, where_to_start, where_to_start, pattern1)
 
  let info_dict = dict.filter(
    info_dict,
    fn(_, value) {
      value |> infra.triples_first != "will_be_trashed"
    }
  )
 
  case match {
    True -> {
      let assert Ok(blame_node) = infra.get_at(atomized_children, start)
 
      use pattern2_vxmls <- result.try(replace(blame_node.blame, info_dict, pattern2))
 
      let children_before_match =
        list.flatten([
          list.take(atomized_children, start),
          [end_node(infra.blame_us("..."))],
        ])
 
      let children_after_match = list.flatten([atomized_children |> list.drop(end + 1)])
 
      let reassembled =
        list.flatten([
          children_before_match,
          pattern2_vxmls,
          children_after_match,
        ])
 
      let next_where_to_start =
        list.length(children_before_match)
        + list.length(pattern2_vxmls)
        + where_to_start
 
      case list.length(atomized_children) - next_where_to_start >= list.length(pattern1) {
        True -> {
          let rest =
            match_until_end(
              reassembled,
              pattern1,
              pattern2,
              next_where_to_start,
            )
          rest
        }
        False -> reassembled |> Ok
      }
    }
    False -> atomized_children |> Ok
  }
}
 
fn atomize_text_node(vxml: VXML) -> List(VXML) {
  let assert T(blame, blamed_contents) = vxml
  blamed_contents
  |> list.map(fn(blamed_content) {
    let BlamedContent(line_blame, line_content) = blamed_content
    line_content
    |> string.split(" ")
    |> list.map(fn(word) { word_to_node(line_blame, word) })
    |> list.intersperse(space_node(line_blame))
    |> list.filter(fn(node) {
      case node {
        V(_, "__OneWord", attr, _) -> {
          let assert [BlamedAttribute(_, "val", word)] = attr
          !{ word |> string.is_empty }
        }
        _ -> True
      }
    })
  })
  |> list.intersperse([line_node(blame)])
  |> list.flatten
  |> list.append([end_node(blame)])
}
 
fn atomize_if_t_or_a_with_single_t_child(vxml: VXML) -> List(VXML) {
  case vxml {
    V(blame, "a", attributes, [T(_, _) as t]) -> {
      [V(blame, "a", attributes, atomize_text_node(t))]
    }
    V(blame, "InChapterLink", attributes, [T(_, _) as t]) -> {
      [V(blame, "InChapterLink", attributes, atomize_text_node(t))]
    }
    V(_, _, _, _) -> [vxml]
    T(_, _) -> atomize_text_node(vxml)
  }
}
 
fn atomize_maybe(children: List(VXML)) -> Result(List(VXML), Nil) {
  case
    list.any(children, fn(v) {
      infra.is_v_and_tag_equals(v, "a")
      || infra.is_v_and_tag_equals(v, "InChapterLink")
    })
  {
    True -> 
      children
      |> list.map(atomize_if_t_or_a_with_single_t_child)
      |> list.flatten
      |> Ok
    False -> Error(Nil)
  }
}
 
fn transform(
  vxml: VXML,
  extra: ExtraTransformed,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(b, tag, attributes, children) -> {
      use atomized_children <- infra.on_error_on_ok(
        over: atomize_maybe(children),
        with_on_error: fn(_) { Ok(vxml) },
      )

      let updated_children =
        extra
        |> list.try_fold(
          atomized_children,
          fn(acc, x) {
            let #(pattern1, pattern2) = x
            match_until_end(acc, pattern1, pattern2, 0)
          }
        )
      use updated_children <- result.try(updated_children)
      updated_children
        |> deatomize_vxmls([])
        |> pair.first
        |> V(b, tag, attributes, _)
        |> Ok
    }
    _ -> Ok(vxml)
  }
}
 
fn is_variable(token: String) -> Option(Int) {
  let length = string.length(token)
  let start = string.slice(token, 0, 1)
  let mid = token |> string.drop_start(1) |> string.drop_end(1)
  let end = string.slice(token, length - 1, length)
  case start == "_", end == "_", int.parse(mid) {
    True, True, Ok(x) -> Some(x)
    _, _, _ -> None
  }
}
 
fn keep_some_remove_none_and_unwrap(l: List(Option(a))) -> List(a) {
  l
  |> list.filter_map(fn(x) {
    case x {
      Some(x) -> Ok(x)
      None -> Error(Nil)
    }
  })
}
 
fn xmlm_tag_name(t: xmlm.Tag) -> String {
  let xmlm.Tag(xmlm.Name(_, ze_name), _) = t
  ze_name
}
 
fn xmlm_attribute_equals(t: xmlm.Attribute, name: String) -> Bool {
  case t {
    xmlm.Attribute(xmlm.Name(_, ze_name), _) if ze_name == name -> True
    _ -> False
  }
}
 
fn match_tag_and_children(
  xmlm_tag: xmlm.Tag,
  children: List(Result(LinkPattern, DesugaringError)),
) {
  use tag_content_patterns <- result.try(children |> result.all)
  let tag_content_patterns = tag_content_patterns |> list.flatten
  use <- infra.on_true_on_false(
    xmlm_tag_name(xmlm_tag) == "root",
    Ok(tag_content_patterns),
  )
  use <- infra.on_false_on_true(
    xmlm_tag_name(xmlm_tag) == "a" || xmlm_tag_name(xmlm_tag) == "InChapterLink",
    Error(DesugaringError(
      infra.blame_us(""),
      "pattern tag is not '<a>' or <InChapterLink> it is "
        <> xmlm_tag_name(xmlm_tag),
    )),
  )
  use href_attribute <- result.then(
    xmlm_tag.attributes
    |> list.find(xmlm_attribute_equals(_, "href"))
    |> result.map_error(fn(_) {
      DesugaringError(
        infra.blame_us(""),
        "<a> pattern tag missing 'href' attribute",
      )
    }),
  )
  let class_attribute =
    xmlm_tag.attributes
    |> list.find(xmlm_attribute_equals(_, "class"))
 
  let xmlm.Attribute(_, value) = href_attribute
  use value <- result.then(
    int.parse(value)
    |> result.map_error(fn(_) {
      DesugaringError(
        infra.blame_us(""),
        "<a> pattern 'href' attribute not an int",
      )
    }),
  )
 
  let classes = case class_attribute {
    Ok(x) -> {
      let xmlm.Attribute(_, value) = x
      value
    }
    Error(_) -> ""
  }
 
  Ok([A(xmlm_tag_name(xmlm_tag), classes, value, tag_content_patterns)])
}
 
fn regex_splits_to_optional_tokens(splits: List(String)) -> Option(LinkPattern) {
  splits
  |> list.filter(fn(x) { !{ x |> string.is_empty } })
  |> list.map(fn(x) {
    case is_variable(x) {
      Some(x) -> Variable(x)
      None -> Word(x)
    }
  })
  |> Some
}
 
fn word_to_optional_tokens(word: String) -> Option(LinkPattern) {
  case word {
    "" -> None
    _ -> Some([Word(word)])
  }
}
 
fn split_variables(words: List(String)) -> List(Option(LinkPattern)) {
  let assert Ok(re) = regexp.from_string("(_[0-9]+_)")
  words
  |> list.map(fn(word) {
    case regexp.check(re, word) {
      False -> word_to_optional_tokens(word)
      True -> {
        regexp.split(re, word)
        // example of splits for _1_._2_ ==> ["", "_1_", ".", "_2_", ""]
        |> regex_splits_to_optional_tokens
      }
    }
  })
}
 
fn match_link_content(content: String) -> Result(LinkPattern, DesugaringError) {
  content
  |> string.split(" ")
  |> split_variables
  // variables doesn't have to be surrounded by spaces
  |> list.intersperse(Some([Space]))
  |> keep_some_remove_none_and_unwrap
  |> list.flatten
  |> Ok
}
 
fn extra_string_to_link_pattern(
  s: String,
) -> Result(LinkPattern, DesugaringError) {
  case
    xmlm.document_tree(
      xmlm.from_string(s),
      match_tag_and_children,
      match_link_content,
    )
  {
    Ok(#(_, pattern, _)) -> pattern
    Error(input_error) ->
      Error(DesugaringError(infra.blame_us(""), ins(input_error)))
  }
}
 
fn make_sure_attributes_are_quoted(input: String) -> String {
  let assert Ok(pattern) =
    regexp.compile("([a-zA-Z0-9-]+)=([^\"'][^ >]*)", regexp.Options(True, True))
 
  regexp.match_map(pattern, input, fn(match: regexp.Match) {
    case match.submatches {
      [Some(key), Some(value)] -> {
        key <> "=\"" <> value <> "\""
      }
      _ -> match.content
    }
  })
}
 
fn extra_transform(extra: Extra) -> Result(ExtraTransformed, DesugaringError) {
  extra
  |> list.try_map(fn(x) {
    let #(s1, s2) = x
    use pattern1 <- result.try(
      { "<root>" <> s1 <> "</root>" }
      |> make_sure_attributes_are_quoted
      |> extra_string_to_link_pattern,
    )
    use pattern2 <- result.try(
      { "<root>" <> s2 <> "</root>" }
      |> make_sure_attributes_are_quoted
      |> extra_string_to_link_pattern,
    )
    Ok(#(pattern1, pattern2))
  })
}
 
fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  case extra |> extra_transform {
    Ok(transformed_extra) -> fn(node) { transform(node, transformed_extra) }
    Error(error) -> fn(_) { Error(error) }
  }
}
 
fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}
 
type ExtraTransformed =
  List(#(LinkPattern, LinkPattern))
 
type Extra =
  List(#(String, String))
 
/// matches appearance of first String
/// while considering (x) as a variable
/// and replaces it with the second String
/// (x) can be used in second String to use
/// the variable from first String
pub fn rearrange_links(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "rearrange_links",
      option.None,
      "
matches appearance of first String
while considering (x) as a variable
and replaces it with the second String
(x) can be used in second String to use
the variable from first String",
    ),
    desugarer: desugarer_factory(extra),
  )
}
 
 