import gleam/pair
import gleam/io
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
import vxml.{type VXML, V, T, BlamedContent, BlamedAttribute}
import xmlm
import gleam/dict.{type Dict}

type LinkPatternToken {
    Word(String) // (does not contain whitespace)
    Space
    Newline
    Variable(Int)
    A(Int, LinkPattern) // the Int is the href, the List(LinkPatternToken) is the inside of the a-tag
}

type LinkPattern = List(LinkPatternToken)

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
    "__OneNewline",
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
        // if tag is not a or children do not have any a tag elements we skip
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

        let atomizeed_children = list.map(children, fn(x){
          let #(_, atomized) = atomize_text(x)
          atomized
        })
        
        let new_children = list.flatten(atomizeed_children)
        #(True, [V(blame, tag, attributes, new_children)])
        
      // }
      // _ -> [vxml]
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
        V(b, t, a, children) -> {
          let updated_children = deatomize_vxmls(children, []) |> pair.first
          #([V(b, t, a, updated_children)], [])
        }
        _ -> #([], []) // should never happen
      }
      let #(rest_nodes, _) = deatomize_vxmls(rest, accumilated_contents)
      #(list.flatten([nodes, rest_nodes]), [])
    }
  }
}

fn get_list_of_variables(info_dict: Dict(Int, #(String, List(String)))) -> List(String) {
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
    Ok(A(_, _)) | Error(_) -> {
        [end_node(infra.blame_us("..."))]
    }
    _ -> []
  }

}

fn replace(
  parent: VXML,
  info_dict: Dict(Int, #(String, List(String))),
  pattern1: LinkPattern,
  pattern2: LinkPattern,
) -> VXML {
  let assert V(blame, tag, attrs, children) = parent
  
  let new_children =  
  pattern2
  |> list.index_map(fn(token, i){
    case token {
      Word(word) -> {
        list.flatten([[word_to_node(blame, word)], add_end_node_indicator(i + 1, pattern2)])
      }
      Space -> {
        list.flatten([[space_node(blame)], add_end_node_indicator(i + 1, pattern2)])
      }
      Newline -> {
        list.flatten([[line_node(blame)], add_end_node_indicator(i + 1, pattern2)])
      }
      Variable(var) -> {
        let assert Ok(var_value) = info_dict |> get_list_of_variables |> infra.get_at(var - 1)
        list.flatten([[word_to_node(blame, var_value)], add_end_node_indicator(i + 1, pattern2)])
      }
      A(var, sub_pattern) -> {
        let assert Ok(link_info) = info_dict |> dict.get(var)
        let href_value = link_info |> pair.first

        // we need to add EndAtomizedT if there are previous siblings
          [
            V(
              blame,
              "a", 
              [BlamedAttribute(blame, "href", href_value)],
              children
            )
            |> replace(info_dict, pattern1, sub_pattern)
          ]
      }
    }
  })
  V(blame, tag, attrs, new_children |> list.flatten)
}

fn match(
  parent: VXML,
  where_to_start: Int, // which child to use as starting point
  global_index: Int,
  pattern: LinkPattern,
) -> #(
  Bool,
  Int, // Int for tracking matched tokens in the pattern
  Int, // the index of the last found element
  Dict(Int, #(String, List(String))), // the first String is the original href value, the second string is the original text __OneWord "val" payload matched by the `_1_` or whatever)
) {
  let assert V(_, tag, _, children) = parent
  let init_acc = #(False, 0, 0, dict.new())

  let real_children = children
    |> list.drop(where_to_start)

  real_children
    |> list.drop(where_to_start)
    |> list.index_fold(init_acc, fn(acc, child, index){
      let global_index = index + global_index
      let #(_, last_found_index, _, _) = acc

      case pattern |> list.drop(last_found_index) {
        [] -> {
          let #(_, end, last_index, dict) = acc
          #(True, end, last_index, dict)
        }
        [head_token,..] -> {
        
          let #(_, _, _, prev_dict) = acc

          case child {
            V(_, "__OneWord", atts, _) -> {
              let assert [BlamedAttribute(_, "val", word)] = atts
              let #(is_match, original_word) = case head_token {
                // original word is needed for only the variable case . we want to know the value of the word  matched with the variable _x_
                Word(w) -> #(w == word, w)
                Variable(var) -> {
                  // let var =  string.inspect(var)
                  #(True, word)
                }
                _ -> #(False, "")
              }

              let last_found_index = case is_match {
                True -> last_found_index + 1
                False -> 0
              }

              #(is_match, last_found_index, index, dict.insert(prev_dict, global_index * -1, #("__OneWord", [original_word]) ))
            }
            V(_, "__OneSpace", _, _) -> {
              case head_token {
                Space -> #(True, last_found_index + 1, index, dict.insert(prev_dict, global_index * -1, #("__OneSpace", [""]) )) 
                _ -> #(False, 0, index, dict.new())
              }
            }
            V(_, "__OneNewLine", _, _) -> {
              case head_token {
                Newline -> #(True, last_found_index + 1, index, dict.insert(prev_dict, global_index * -1, #("__OneNewLine", [""]) ))
                _ -> #(False, 0, index, dict.new())
              }
            }
            V(_, "a", attrs, _) -> {
              case head_token {
                A(val, sub_pattern) ->{
                  let #(is_match, _, _, new_dict) = match(child, 0, global_index, sub_pattern)

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
                  #(is_match, last_found_index, index, dict.merge(prev_dict, new_dict) )
                }
                _ -> #(False, 0, index, dict.new())
              }
            }
            _ -> #(False, 0, index, dict.new())
          }
        }
      }
    })
}

fn match_until_end(atomized: VXML, pattern1: LinkPattern, pattern2: LinkPattern, where_to_start: Int) -> List(VXML) {
  let #(match, _, end, info_dict) = match(atomized, where_to_start, 0, pattern1)
  let assert V(b, t, a, children) = atomized

  case match {
    True -> {
      let nodes_to_replace = children |> list.drop(list.length(pattern1)) |> list.take(end)

      let assert V(_, _, _, updated_atomized) = replace(V(b, t, a, nodes_to_replace), info_dict, pattern1, pattern2)

      let reassembled = 
        list.flatten([
          list.take(children, end - list.length(pattern1)),
          [end_node(infra.blame_us("..."))],
          updated_atomized,
          list.drop(children, end + 1),
          [end_node(infra.blame_us("..."))],
        ])
      
      vxml.debug_print_vxmls("", reassembled)
      let de_atomized = deatomize_vxmls(reassembled, []) |> pair.first
      vxml.debug_print_vxmls("", de_atomized)
      

      case end < list.length(children)   {
        True -> {
          match_until_end(V(b, t, a, de_atomized), pattern1, pattern2, end + 1)
        }
        False -> {
          de_atomized
        }
      }
    }
    False -> children
  }
}

fn transform(
  vxml: VXML,
  extra: ExtraTransformed,
) -> Result(VXML, DesugaringError) {
  
  case vxml {
    V(b, tag, a, children) -> {
      let updated_childen = extra
        |> list.fold(children, fn(acc, x){
          let #(pattern1, pattern2) = x
          let vxml = V(b, tag, a, acc)

          let assert #(continue, [atomized]) = vxml |> atomize_text
          case continue {
            True -> match_until_end(atomized, pattern1, pattern2, 0)
            False -> children
          }
        })
      Ok(V(b, tag, a, updated_childen))
    }
    _ -> Ok(vxml)
  }
}
 
// *** Transforming input of String, String to LinkPattern, LinkPattern

type ExtraTransformed = List(#(LinkPattern, LinkPattern))

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

fn match_link_content(content: String) -> Result(LinkPattern, DesugaringError) {

  content 
  |> string.split(" ") 
  |> list.map(fn(x) {
    case is_variable(x), x == "" {
      Some(x), _ -> Some(Variable(x))
      None, False -> Some(Word(x))
      None, True -> None
    }
  })
  |> list.intersperse(Some(Space))
  |> list.filter_map(fn(x) {
      case x {
        Some(x) -> Ok(x)
        None -> Error("")
      }
  })
  |> Ok
}

fn extra_string_to_link_pattern(s: String) -> Result(LinkPattern, DesugaringError) {
  let input = xmlm.from_string(s)

  case xmlm.document_tree(
    input,
    fn (xmlm_tag, children) {
      let href_value = xmlm_tag.attributes |> list.find(fn(x) {
        case x {
          xmlm.Attribute(xmlm.Name(_, "href"), _) -> True
          _ -> False
        }
      })
      use tag_content_patterns <- result.try(children |> list.try_map(fn(x) {
        x
      }))
     
      case href_value {
        Ok(xmlm.Attribute(_, value)) -> {
          case int.parse(value) {
            Ok(value) -> Ok([A(value, list.flatten(tag_content_patterns))])
            Error(_) -> Error(DesugaringError(infra.blame_us(""), "href attribute not an int"))
          } 
        }
        Error(_) -> {
          case xmlm_tag {
            xmlm.Tag(xmlm.Name(_, "a"), _) -> Error(DesugaringError(infra.blame_us(""), "href attribute not found"))
            _ -> Ok(list.flatten(tag_content_patterns))
          }
        }
      }
    },
    match_link_content
  ) {
    Ok(#(_, pattern, _)) -> pattern
    Error(input_error) -> {
      input_error |> string.inspect |> DesugaringError(infra.blame_us(""), _) |> Error
    }
  }
}

fn extra_transform(extra: Extra) -> Result(ExtraTransformed, DesugaringError){
  extra
  |>  list.try_map(fn(x){
      let #(s1, s2) = x
      use pattern1 <- result.try({"<root>" <> s1 <> "</root>"} |> extra_string_to_link_pattern)

      // wrap inside root to not get xmln error
      use pattern2 <- result.try({"<root>" <> s2 <> "</root>"} |> extra_string_to_link_pattern)
      Ok(#(pattern1, pattern2))
  })
}
// *** End of extra transformation ***

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  fn(node) { 
    use transformed_extra <- result.try(extra |> extra_transform)
    transform(node, transformed_extra) 
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

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
