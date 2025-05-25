import gleam/io
import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe } as infra
import vxml.{ type BlamedAttribute, type VXML, BlamedAttribute, BlamedContent, T, V }
import xmlm
 
const ins = string.inspect
 
type LinkPatternToken {
  Word(String)    // (does not contain whitespace)
  Space
  ContentVar(Int)
  A(
    String,       // tag name ( for now it's either a or InChapterLink )
    String,       // classes
    Int,          // href variable
    LinkPattern,  // the List(LinkPatternToken) inside of the a-tag
  )
}
 
type LinkPattern =
  List(LinkPatternToken)

type PrefixMatchOnAtomizedList {
  PrefixMatchOnAtomizedList(
    left_unmatched: Int,
    href_var_dict: Dict(Int, VXML),
    content_var_dict: Dict(Int, List(VXML)),
  )
}

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
  result: List(VXML)
) -> List(VXML) {

  let append_word_to_accumlated_contents = fn(blame: Blame, word: String) -> List(vxml.BlamedContent) {
    let #(last_line, other_lines) = case accumulated_contents {
      [last_line, ..other_lines] -> #(last_line, other_lines)
      _ -> #(BlamedContent(blame, ""), [])
    }
    [BlamedContent(..last_line, content: last_line.content <> word), ..other_lines]
  }

  case children {
    [] -> result |> list.reverse
    [first, ..rest] -> {
      case first {
        V(blame, "__OneWord", attributes, _) -> {
          let assert [BlamedAttribute(_, "val", word)] = attributes
          let accumulated_contents = append_word_to_accumlated_contents(blame, word)
          deatomize_vxmls(rest, accumulated_contents, result)
        }

        V(blame, "__OneSpace", _, _) -> {
          let accumulated_contents = append_word_to_accumlated_contents(blame, " ")
          deatomize_vxmls(rest, accumulated_contents, result)
        }

        V(blame, "__OneNewLine", _, _) -> {
          let accumulated_contents = [BlamedContent(blame, ""), ..accumulated_contents]
          deatomize_vxmls(rest, accumulated_contents, result)
        }

        V(blame, "__EndAtomizedT", _, _) -> {
          deatomize_vxmls(rest, [], [T(blame, accumulated_contents |> list.reverse), ..result])
        }

        V(b, "a", a, children) | V(b, "InChapterLink", a, children) -> {
          let V(_, ze_tag, _, _) = first
          let updated_children = deatomize_vxmls(children, [], [])
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
 
          deatomize_vxmls(rest, accumulated_contents, [V(b, ze_tag, a, updated_children) ,..result])
        }
        V(_, _, _, _) -> deatomize_vxmls(rest, [], result)
        _ -> panic as "should not happen"
      }
    }
  }
}
 
fn fast_forward_past_spaces(
  atomized: List(VXML),
) -> List(VXML) {
  list.drop_while(atomized, infra.tag_is_one_of(_, ["__OneSpace", "__OneNewLine", "__EndAtomizedT"]))
}

fn fast_forward_past_end_t(
  atomized: List(VXML),
) -> List(VXML) {
  list.drop_while(atomized, infra.tag_equals(_, "__EndAtomizedT"))
}

fn match_internal(
  atomized: List(VXML),
  pattern: LinkPattern,
  href_dict_so_far: Dict(Int, VXML),
  content_var_dict_so_far: Dict(Int, List(VXML)),
) -> Option(PrefixMatchOnAtomizedList) {
  let atomized = fast_forward_past_end_t(atomized)

  case pattern {
    [] -> Some(PrefixMatchOnAtomizedList(
      left_unmatched: atomized |> list.length,
      href_var_dict: href_dict_so_far,
      content_var_dict: content_var_dict_so_far,
    ))

    [ContentVar(z), ..pattern_rest] -> {
      let assert True = list.is_empty(pattern_rest)
      let assert Error(Nil) = dict.get(content_var_dict_so_far, z)
      let content_var_dict_so_far = dict.insert(content_var_dict_so_far, z, atomized)

      Some(PrefixMatchOnAtomizedList(
        left_unmatched: 0,
        href_var_dict: href_dict_so_far,
        content_var_dict: content_var_dict_so_far
      ))
    }

    [Word(word), ..pattern_rest] ->
      case atomized {
        [V(_, "__OneWord", _, _) as v, ..atomized_rest] -> {
          let assert Some(attr) = infra.get_attribute_by_name(v, "val")
          case attr.value == word {
            True -> match_internal(
              atomized_rest,
              pattern_rest,
              href_dict_so_far,
              content_var_dict_so_far,
            )
            False -> None
          }
        }
        _ -> None
      }

    [Space, ..pattern_rest] -> case atomized {
      [V(_, "__OneSpace", _, _), ..atomized_rest] -> {
        match_internal(
          atomized_rest |> fast_forward_past_spaces,
          pattern_rest,
          href_dict_so_far,
          content_var_dict_so_far,
        )
      }
      _ -> {
        None
      }
    }

    [A(_, _, href_int, internal_tokens,), ..pattern_rest] -> case atomized {
      [V(_, tag, _, children) as v, ..atomized_rest] if tag == "a" || tag == "InChapterLink" -> {
        let href_dict_so_far = dict.insert(href_dict_so_far, href_int, v)
        case match_internal(
          children,
          internal_tokens,
          href_dict_so_far,
          content_var_dict_so_far,
        ) {
          None -> None
          Some(PrefixMatchOnAtomizedList(left_unmatched, href_dict_so_far, content_var_dict_so_far)) -> {
            case left_unmatched > 0 {
              True -> None
              False -> match_internal(
                atomized_rest,
                pattern_rest,
                href_dict_so_far,
                content_var_dict_so_far,
              )
            }
          }
        }
      }

      _ -> None
    }
  }
}

fn match(
  atomized: List(VXML),
  pattern: LinkPattern,
) -> Option(PrefixMatchOnAtomizedList) {
  match_internal(
    atomized,
    pattern,
    dict.new(),
    dict.new(),
  )
}

fn prefix_match_to_atomized_list(
  default_blame: Blame,
  pattern: List(LinkPatternToken),
  match: PrefixMatchOnAtomizedList,
  already_ready: List(VXML),
) -> List(VXML) {
  case pattern {
    [] -> already_ready |> list.reverse |> list.append([end_node(default_blame)])
    [p, ..pattern_rest] -> {
      case p {
        Word(word) -> prefix_match_to_atomized_list(
          default_blame,
          pattern_rest,
          match,
          [word_to_node(default_blame, word), ..already_ready],
        )

        Space -> prefix_match_to_atomized_list(
          default_blame,
          pattern_rest,
          match,
          [space_node(default_blame), ..already_ready],
        )

        ContentVar(z) -> {
          let assert Ok(z_vxmls) = dict.get(match.content_var_dict, z)
          prefix_match_to_atomized_list(
            default_blame,
            pattern_rest,
            match,
            [
              z_vxmls,
              already_ready,
            ] |> list.flatten,
          )
        }

        A(_, classes, href_int, internal_pattern) -> {
          let assert Ok(vxml) = dict.get(match.href_var_dict, href_int)
          let assert V(blame, tag, attributes, _) = vxml
          let a_node = V(
            blame,
            tag,
            attributes |> infra.add_to_class_attribute(blame, classes),
            prefix_match_to_atomized_list(
              vxml.blame,
              internal_pattern,
              match,
              [],
            ),
          )
          prefix_match_to_atomized_list(
            default_blame,
            pattern_rest,
            match,
            [a_node, end_node(blame), ..already_ready],
          )
        }
      }
    }
  }
}

fn replace(
  atomized: List(VXML),
  pattern: LinkPattern,
  match: PrefixMatchOnAtomizedList,
) -> List(VXML) {
  let to_be_dropped = list.length(atomized) - match.left_unmatched
  let assert True = 0 <= to_be_dropped && to_be_dropped <= list.length(atomized)
  let assert Ok(V(first_blame, _, _, _)) = list.first(atomized)
  let tail = list.drop(atomized, to_be_dropped)
  let head = prefix_match_to_atomized_list(first_blame, pattern, match, [])
  [head, tail] |> list.flatten
}

fn match_until_end_internal(
  atomized: List(VXML),
  pattern1: LinkPattern,
  pattern2: LinkPattern,
  already_done: List(VXML),
) -> List(VXML) {
  case atomized {
    [] -> already_done |> list.reverse 
    [first, ..rest] -> case match(atomized, pattern1) {
      None -> match_until_end_internal(
        rest,
        pattern1,
        pattern2,
        [first, ..already_done],
      )

      Some(match) -> {
        let assert [first, ..rest] = replace(atomized, pattern2, match)
        match_until_end_internal(
          rest,
          pattern1,
          pattern2,
          [first, ..already_done],
        )
      }
    }
  }
}

fn match_until_end(
  atomized: List(VXML),
  patterns: #(LinkPattern, LinkPattern),
) -> List(VXML) {
  let #(pattern1, pattern2) = patterns
  match_until_end_internal(atomized, pattern1, pattern2, [])
}

 
fn atomize_text_node(vxml: VXML) -> List(VXML) {
  let assert T(blame, blamed_contents) = vxml
  blamed_contents
  |> list.map(fn(blamed_content) {
    blamed_content.content
    |> string.split(" ")
    |> list.map(fn(word) { word_to_node(blamed_content.blame, word) })
    |> list.intersperse(space_node(blamed_content.blame))
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
      use atomized <- infra.on_error_on_ok(
        over: atomize_maybe(children),
        with_on_error: fn(_) { Ok(vxml) },
      )
      list.fold(
        extra,
        atomized,
        match_until_end,
      )
      |> deatomize_vxmls([], [])
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
  use tag_content_patterns <- result.then(children |> result.all)
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
  let xmlm.Attribute(_, value) = 
    href_attribute
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
      Some(x) -> ContentVar(x)
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

fn get_content_vars(
  pattern2: LinkPattern,
) -> List(Int) {
  list.map(pattern2, fn(token){
    case token {
      ContentVar(var) -> [var]
      A(_, _, _, sub_pattern) -> get_content_vars(sub_pattern)
      _ -> []
    }
  })
  |> list.flatten
}

fn get_hreft_vars(
  pattern2: LinkPattern,
) -> List(Int) {
  list.map(pattern2, fn(token){
    case token {
      A(_, _, var, _) -> [var]
      _ -> []
    }
  })
  |> list.flatten
}

fn check_each_content_var_is_sourced(pattern2: LinkPattern, source_vars: List(Int)) -> Result(Nil, Int) {
  let content_vars = get_content_vars(pattern2)
  case list.find(content_vars, fn(var){
    !{ list.contains(source_vars, var) }
  }) {
    Ok(var) -> Error(var)
    Error(_) -> Ok(Nil)
  }
}

fn check_each_href_var_is_sourced(pattern2: LinkPattern, href_vars: List(Int)) -> Result(Nil, Int) {
  let vars = get_hreft_vars(pattern2)
  case list.find(vars, fn(var){
    !{ list.contains(href_vars, var) }
  }) {
    Ok(var) -> Error(var)
    Error(_) -> Ok(Nil)
  }
}

fn collect_unique_content_vars(pattern1: LinkPattern) -> Result(List(Int), Int) {
  let vars = get_content_vars(pattern1)
  case infra.get_duplicate(vars) {
    None -> Ok(vars)
    Some(int) -> Error(int)
  }
}

fn collect_unique_href_vars(pattern1: LinkPattern) -> Result(List(Int), Int) {
  let vars = get_hreft_vars(pattern1)
  case infra.get_duplicate(vars) {
    None -> Ok(vars)
    Some(int) -> Error(int)
  }
}
 
fn string_pair_to_link_pattern_pair(string_pair: #(String, String)) -> Result(#(LinkPattern, LinkPattern), DesugaringError) {
  let #(s1, s2) = string_pair

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
}

fn extra_transform(extra: Extra) -> Result(ExtraTransformed, DesugaringError) {
  extra
  |> list.try_map(fn(string_pair) {
    let #(s1, s2) = string_pair
    use #(pattern1, pattern2) <- result.then(string_pair_to_link_pattern_pair(string_pair))

    use unique_href_vars <- result.then(
      collect_unique_href_vars(pattern1)
      |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Source pattern " <> s1 <>" has duplicate declaration of href variable: " <> ins(var) ) })
    )

    use unique_content_vars <- result.then(
      collect_unique_content_vars(pattern1)
      |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Source pattern " <> s1 <>" has duplicate declaration of content variable: " <> ins(var)) })
    )

    use _ <- result.then(
      check_each_href_var_is_sourced(pattern2, unique_href_vars)
      |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Target pattern " <> s2 <> " has a declaration of unsourced href variable: " <> ins(var)) })
    )

    use _ <- result.then(
      check_each_content_var_is_sourced(pattern2, unique_content_vars)
      |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Target pattern " <> s2 <> " has a declaration of unsourced content variable: " <> ins(var)) })
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
 
 