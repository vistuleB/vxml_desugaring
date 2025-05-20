import gleam/io
import gleam/regexp
import gleam/pair
import gleam/result
import blamedlines.{type Blame, Blame}
import gleam/int
import gleam/string
import gleam/list
import gleam/option.{Some, None, type Option}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V, T, BlamedContent, BlamedAttribute, type BlamedAttribute}
import xmlm
import gleam/dict.{type Dict}

const ins = string.inspect
type LinkPatternToken {
    Word(String) // (does not contain whitespace)
    Space
    Variable(Int)
    A(String, Int, LinkPattern) // the String for classes, the Int is the href, the List(LinkPatternToken) is the inside of the a-tag
}

type LinkPattern = List(LinkPatternToken)

type InfoDict = Dict(
  Int, // the href link variable ( respresenting the Int  In LinkPatternToken A(String, Int, LinkPattern)  )
  #(
    String, // the original href value
    List(String) // the original text __OneWord "val" payload matched by the `_1_`
  )
)

type MatchingAccumilator = #(
  Bool, // whether the pattern has been matched
  Int, // for tracking matched tokens in the pattern
  Int, // index of the first element matched
  Int, // index of the last element matched
  InfoDict,
)

fn word_to_node(blame: Blame, word: String) {
  V(
    blame,
    "__OneWord",
    [
      BlamedAttribute(
        infra.blame_us("..."),
        "val",
        word
      )
    ],
    [],
  )
}

fn space_node(blame: Blame) {
  V(
    blame,
    "__OneSpace",
    [],
    [],
  )
}

fn line_node(blame: Blame) {
  V(
    blame,
    "__OneNewLine",
    [],
    [],
  )
}

fn end_node(blame: Blame) {
  V(
    blame,
    "__EndAtomizedT",
    [],
    [],
  )
}

fn atomize_text(
  vxml: VXML,
) -> #(Bool, List(VXML)) // bool for whether the vxml has a elements or not
{
  case vxml {
    V(blame, tag, attributes, children) -> {
      let has_a = list.any(children, fn(x) {
        tag == "a" || case x {
          V(_, "a", _, _) -> True
          _ -> False
        }
      })

      use <- infra.on_false_on_true(
        over: has_a,
        with_on_false: #(False, [vxml])
      )

      let atomized_children = list.map(children, fn(x) {
        let #(_, atomized) = atomize_text(x)
        atomized
      })
      
      let new_children = list.flatten(atomized_children)

      #(True, [V(blame, tag, attributes, new_children)])
    }

    T(blame, blamed_contents) -> {
      let atomized = list.map(
        blamed_contents,
        fn (blamed_content) {
          let BlamedContent(line_blame, line_content) = blamed_content
          line_content
            |> string.split(" ")
            |> list.map(
              fn(word) { word_to_node(line_blame, word) }
            )
            |> list.intersperse(space_node(line_blame))
            |> list.filter(fn(node){
              case node {
                V(_, "__OneWord", attr, _) -> {
                  let assert [BlamedAttribute(_, "val", word)] = attr
                  !{ word |> string.is_empty }
                }
                _ -> True
              }
            })
        }
      )
      |> list.intersperse([line_node(blame)])
      |> list.flatten
      |> list.append([end_node(blame)])

      #(True, atomized)
    }
  }
}

fn deatomize_vxmls(
  children: List(VXML),
  accumilated_contents: List(vxml.BlamedContent),
) -> #(List(VXML), List(vxml.BlamedContent)) {
  case children {
    [] -> #([], [])
    [first, ..rest] -> {
      let #(nodes, accumilated_contents) = case first {
        V(blame, "__OneWord", attributes, _) -> {
          let assert [BlamedAttribute(_, "val", word)] = attributes
          let last_line = case list.last(accumilated_contents){
            Ok(last_line) -> last_line
            Error(_) -> BlamedContent(blame, "")
          }
          let last_line = BlamedContent(..last_line, content: last_line.content <> word)
          let accumilated_contents = accumilated_contents
            |> list.length
            |> int.add(-1)
            |> list.take(accumilated_contents, _)
            |> list.append([last_line])

          #([], accumilated_contents)
        }
        V(blame, "__OneSpace", _, _) -> {
          let last_line = case list.last(accumilated_contents){
            Ok(last_line) -> last_line
            Error(_) -> BlamedContent(blame, "")
          }
          let last_line = BlamedContent(..last_line, content: last_line.content <> " ")
          let accumilated_contents = accumilated_contents
            |> list.length 
            |> int.add(-1)
            |> list.take(accumilated_contents, _)
            |> list.append([last_line])
          
          #([], accumilated_contents)
        }
        V(blame, "__OneNewLine", _, _) -> {
          let accumilated_contents = accumilated_contents
            |> list.append([BlamedContent(blame, "")])
          
          #([], accumilated_contents)
        }
        V(blame, "__EndAtomizedT", _, _) -> {
          #([T(blame, accumilated_contents)], [])
        }
        V(b, "a", a, children) -> {
          let updated_children = deatomize_vxmls(children, []) |> pair.first
          // check if next is a new line to add a space 
          let accumilated_contents = case rest {
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

          #([V(b, "a", a, updated_children)], accumilated_contents)
        }
        V(_, _, _, _) -> {
          #([first], [])
        }
        _ -> #([], []) // should never happen
      }
      let #(rest_nodes, _) = deatomize_vxmls(rest, accumilated_contents)
      #(list.flatten([nodes, rest_nodes]), [])
    }
  }
}

fn get_list_of_variables(info_dict: InfoDict) -> List(String) {
  info_dict
  |> dict.map_values(fn(_, value){
    value |> pair.second
  })
  |> dict.values
  |> list.flatten
}

fn add_end_node_indicator(next_index: Int, pattern: LinkPattern) -> List(VXML) {
  let next_token = pattern |> infra.get_at(next_index)
  case next_token {
    Ok(A(_, _, _)) | Error(_) -> {
        [end_node(infra.blame_us("..."))]
    }
    _ -> []
  }

}

fn replace(
  parent: VXML,
  info_dict: InfoDict,
  pattern2: LinkPattern,
) -> Result(VXML, DesugaringError) {
  let assert V(blame, tag, attrs, _) = parent
  
  let new_children =  
  pattern2
  |> list.index_map(fn(token, i){
    case token {
      Word(word) -> {
        list.flatten([[word_to_node(blame, word)], add_end_node_indicator(i + 1, pattern2)]) |> Ok
      }
      Space -> {
        list.flatten([[space_node(blame)], add_end_node_indicator(i + 1, pattern2)])
        |> Ok
      }
      // Newline -> {
      //   list.flatten([[line_node(blame)], add_end_node_indicator(i + 1, pattern2)])
      //   |> Ok
      // }
      Variable(var) -> {
        let assert Ok(var_value) = info_dict |> get_list_of_variables |>  infra.get_at(var - 1)
        list.flatten([[word_to_node(blame, var_value)], add_end_node_indicator(i + 1, pattern2)])
        |> Ok
      }
      A(classes, var, sub_pattern) -> {
        use link_info <- result.try(info_dict |> dict.get(var) |> result.map_error(fn(_){
          DesugaringError(blame, "Href " <> ins(var) <> " was not found")
        }))
        let href_value = link_info |> pair.first

        let new_a_node = V(
            blame,
            "a", 
            [BlamedAttribute(blame, "href", href_value),
            BlamedAttribute(blame, "class", classes)],
            []
          )
        use new_new_a_node <- result.try(replace(new_a_node, info_dict, sub_pattern))
      
        [new_new_a_node] |> Ok
      }
    }
  })
  |> list.try_map(fn(result){
    result
  })

  use new_children <- result.try(new_children)

  Ok(V(blame, tag, attrs, new_children |> list.flatten))
}

fn check_pattern_is_completed(acc: MatchingAccumilator, pattern: LinkPattern) -> MatchingAccumilator {
  let #(is_match, last_found_index, start, end, dict) = acc
  // extra check to see if the pattern is fully completed 
  case is_match && last_found_index < list.length(pattern) {
    True -> {
      #(False, last_found_index, start, end, dict)
    }
    _ -> acc
  }
}

fn match_word(acc: MatchingAccumilator, attrs: List(BlamedAttribute), token: LinkPatternToken, global_index: Int) -> MatchingAccumilator {
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
  #(is_match, last_found_index, start, global_index, dict.insert(prev_dict, global_index * -1, #("will_be_trashed", [original_word]) ))
}

fn match_space_or_line(next_child: Result(VXML, Nil), acc: MatchingAccumilator, token: LinkPatternToken, global_index: Int) -> MatchingAccumilator {
  let #(prev_is_match, last_found_index, start, _, prev_dict) = acc
  let start = update_start_index(start, global_index, True, prev_is_match)

  let new_last_found_index = case next_child {
    Ok(V(_, "__OneSpace", _, _)) | Ok(V(_, "__OneNewLine", _, _)) -> {
      last_found_index
    }
    _ -> last_found_index + 1
  }
  case token {
    Space -> #(True, new_last_found_index, start, global_index, dict.insert(prev_dict, global_index * -1, #("will_be_trashed", [""]) ))
    // Newline, Newline -> #(True, last_found_index + 1, start, global_index, dict.insert(prev_dict, global_index * -1, #("will_be_trashed", [""]) )) 
    _ -> #(False, 0, start, global_index, dict.new())
  }
}

fn match_a(acc: MatchingAccumilator, child: VXML, token: LinkPatternToken, global_index: Int) -> MatchingAccumilator {
  let #(prev_is_match, last_found_index, start, _, prev_dict) = acc
  let assert V(_, _, attrs, _) = child
  case token {
    A(_, val, sub_pattern) -> {


      let #(is_match, _, _,_, new_dict) = match(child, 0, global_index, sub_pattern)


      let assert Ok(BlamedAttribute(_, _, href_value)) = list.find(attrs, fn(x) {
        case x {
          BlamedAttribute(_, "href", _) -> True
          _ -> False
        }
      })
      // get value of variables inside a text
      let words = new_dict |> dict.map_values(fn(_, value){
        value |> pair.second
      })
      |> dict.values
      |> list.flatten

      let new_dict = 
        dict.new() 
        |> dict.insert(val, #(href_value, words))
      
      let last_found_index = case is_match {
        True -> last_found_index + 1
        False -> 0
      }

      let start = update_start_index(start, global_index, is_match, prev_is_match)

      #(is_match, last_found_index, start, global_index, dict.merge(prev_dict, new_dict) )
    }
    _ -> #(False, 0, start, global_index, dict.new())
  }
}

fn update_start_index(start_index: Int, global_index: Int, is_match: Bool, prev_is_match: Bool) -> Int {
  case is_match, prev_is_match {
    True, True -> start_index
    _, _ -> global_index
  }
}

fn match(
  parent: VXML,
  where_to_start: Int, // which child to use as starting point
  global_index: Int,
  pattern: LinkPattern,
) -> MatchingAccumilator {
  let assert V(_, _, _, children) = parent
  let init_acc = #(False, 0, 0, 0, dict.new())

  children
    |> list.drop(where_to_start)
    |> list.index_fold(init_acc, fn(acc, child, index){
      let #(_, last_found_index, start, end, prev_dict) = acc
      let global_index = index + global_index
      let next_child = infra.get_at(children, index + 1)

      case pattern |> list.drop(last_found_index) {
        [] -> {
          #(True, last_found_index, start, end, prev_dict)
        }
        [head_token,..] -> {
          case child {
            V(_, "__OneWord", attrs, _) -> match_word(acc, attrs, head_token, global_index)
            V(_, "__OneSpace", _, _) | V(_, "__OneNewLine", _, _) -> match_space_or_line(next_child, acc, head_token, global_index)
            // V(_, "__OneNewLine", _, _) -> match_space_or_line(Newline ,acc, head_token, global_index)
            V(_, "a", _, _) -> match_a(acc, child, head_token, global_index)
            _ -> acc
          }
        }
      }
    })
    |> check_pattern_is_completed(pattern)
}

fn match_until_end(
  atomized: VXML,
  pattern1: LinkPattern,
  pattern2: LinkPattern,
  where_to_start: Int,
) -> Result(List(VXML), DesugaringError) {

  let #(match, _, start, end, info_dict) = match(atomized, where_to_start, where_to_start, pattern1)
  let assert V(b, t, a, children) = atomized
  // vxml.debug_print_vxmls(t, [atomized])

  let info_dict = dict.filter(info_dict, fn(_, value){
    value |> pair.first != "will_be_trashed"
  })

  case match {
    True -> {
      use updated_node <- result.try(replace(atomized, info_dict, pattern2))
      let assert V(_, _, _, updated_atomized) = updated_node

      let children_before_match =  list.flatten([
          list.take(children, start),
          [end_node(infra.blame_us("..."))] 
      ])

      let children_after_match = list.flatten([
          children |> list.drop(end + 1),
      ])

      let reassembled = 
        list.flatten([
          children_before_match,
          updated_atomized,
          children_after_match,
        ])
  

      let next_where_to_start = list.length(children_before_match) + list.length(updated_atomized) + where_to_start


      case list.length(children) - next_where_to_start  >= list.length(pattern1)   {
        True -> {
          let rest = match_until_end(V(b, t, a, reassembled), pattern1, pattern2, next_where_to_start)
          rest
        }
        False -> {
          deatomize_vxmls(reassembled, []) |> pair.first |> Ok
        }
      }
    }
    False -> deatomize_vxmls(children, []) |> pair.first |> Ok
  }
}

fn atomize_text_node(
  vxml: VXML
) -> List(VXML) {
  let assert T(blame, blamed_contents) = vxml
  blamed_contents
  |> list.map(
    fn (blamed_content) {
      let BlamedContent(line_blame, line_content) = blamed_content
      line_content
        |> string.split(" ")
        |> list.map(
          fn(word) { word_to_node(line_blame, word) }
        )
        |> list.intersperse(space_node(line_blame))
        |> list.filter(fn(node){
          case node {
            V(_, "__OneWord", attr, _) -> {
              let assert [BlamedAttribute(_, "val", word)] = attr
              !{ word |> string.is_empty }
            }
            _ -> True
          }
        })
    }
  )
  |> list.intersperse([line_node(blame)])
  |> list.flatten
  |> list.append([end_node(blame)])
}

fn atomize_if_t_or_a_with_single_t_child(
  vxml: VXML
) -> List(VXML) {
  case vxml {
    V(blame, "a", attributes, [T(_, _) as t]) -> {
      [V(blame, "a", attributes, atomize_text_node(t))]
    }
    V(_, _, _, _) -> [vxml]
    T(_, _) -> atomize_text_node(vxml)
  }
}

fn atomize_maybe(
  vxml: VXML,
) -> #(Bool, VXML) {
  let assert V(blame, tag, attributes, children) = vxml
  let #(has_a, new_children) = case list.any(children, infra.is_v_and_tag_equals(_, "a")) {
    True -> #(True, children |> list.map(atomize_if_t_or_a_with_single_t_child) |> list.flatten)
    False -> #(False, children)
  }
  #(has_a, V(blame, tag, attributes, new_children))
}

fn transform(
  vxml: VXML,
  extra: ExtraTransformed,
) -> Result(VXML, DesugaringError) {
  
  case vxml {
    V(b, tag, attributes, children) -> {
      let updated_childen = 
        extra
        |> list.try_fold(
          children,
          fn(acc, x){
            let #(pattern1, pattern2) = x
            let vxml = V(b, tag, attributes, acc)
            let #(continue, atomized) = vxml |> atomize_maybe

            case continue {
              True ->{
                // vxml.debug_print_vxmls("", [atomized])
                 match_until_end(atomized, pattern1, pattern2, 0)
                 }
              False -> Ok(children)
            }
          }
        )
      use updated_childen <- result.try(updated_childen)
      Ok(V(b, tag, attributes, updated_childen))
    }
    _ -> Ok(vxml)
  }
}
 
fn is_variable(token: String) -> Option(Int)  {
  let length = string.length(token)
  let start = string.slice(token, 0, 1)
  let mid = token |> string.drop_start(1) |> string.drop_end(1)
  let end = string.slice(token, length - 1, length)
  case start == "_" , end == "_" , int.parse(mid)  {
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

fn match_tag_and_children(xmlm_tag: xmlm.Tag, children: List(Result(LinkPattern, DesugaringError))) {
  use tag_content_patterns <- result.try(children |> result.all)
  let tag_content_patterns = tag_content_patterns |> list.flatten
  use <- infra.on_true_on_false(
    xmlm_tag_name(xmlm_tag) == "root",
    Ok(tag_content_patterns),
  )
  use <- infra.on_false_on_true(
    xmlm_tag_name(xmlm_tag) == "a",
    Error(DesugaringError(infra.blame_us(""), "pattern tag is not '<a>' is " <> xmlm_tag_name(xmlm_tag)))
  )
  use href_attribute <- result.then(
    xmlm_tag.attributes
    |> list.find(xmlm_attribute_equals(_, "href"))
    |> result.map_error(fn(_) { DesugaringError(infra.blame_us(""), "<a> pattern tag missing 'href' attribute") })
  )

  let class_attribute =
    xmlm_tag.attributes
    |> list.find(xmlm_attribute_equals(_, "class"))
    

  let xmlm.Attribute(_, value) = href_attribute
  use value <- result.then(
    int.parse(value)
    |> result.map_error(fn(_) { DesugaringError(infra.blame_us(""), "<a> pattern 'href' attribute not an int") })
  )

  let classes = case class_attribute {
    Ok(x) -> {
      let xmlm.Attribute(_, value) = x
      value
    }
    Error(_) -> ""
  }

  Ok([A(classes, value, tag_content_patterns)])
}

fn regex_splits_to_optional_tokens(splits: List(String)) -> Option(LinkPattern) {
  splits
  |> list.filter(fn(x){ !{ x |> string.is_empty } })
  |> list.map(fn(x){
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
  |> split_variables // variables doesn't have to be surrounded by spaces
  |> list.intersperse(Some([Space]))
  |> keep_some_remove_none_and_unwrap
  |> list.flatten
  |> Ok
}

fn extra_string_to_link_pattern(s: String) -> Result(LinkPattern, DesugaringError) {
  case xmlm.document_tree(
    xmlm.from_string(s),
    match_tag_and_children,
    match_link_content
  ) {
    Ok(#(_, pattern, _)) -> pattern
    Error(input_error) -> Error(DesugaringError(infra.blame_us(""), ins(input_error)))
  }
}

fn make_sure_attributes_are_quoted(input: String) -> String {
  let assert Ok(pattern) = regexp.compile("([a-zA-Z0-9-]+)=([^\"'][^ >]*)", regexp.Options(True, True))

  regexp.match_map(
    pattern,
    input,
    fn(match: regexp.Match) {
      case match.submatches {
        [Some(key), Some(value)] -> {
          key <> "=\"" <> value <> "\""
        }
        _ -> match.content
      }
    }
  )
}

fn extra_transform(extra: Extra) -> Result(ExtraTransformed, DesugaringError){
  extra
  |>  list.try_map(fn(x) {
    let #(s1, s2) = x
    use pattern1 <- result.try({"<root>" <> s1 <> "</root>"} |> make_sure_attributes_are_quoted |> extra_string_to_link_pattern)
    use pattern2 <- result.try({"<root>" <> s2 <> "</root>"} |> make_sure_attributes_are_quoted |> extra_string_to_link_pattern)
    Ok(#(pattern1, pattern2))
  })
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  case extra |> extra_transform {
    Ok(transformed_extra) -> fn(node) { 
      transform(node, transformed_extra) 
    }
    Error(error) -> fn(_) { Error(error) }
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type ExtraTransformed = List(#(LinkPattern, LinkPattern))
type Extra = List(#(String, String))

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
