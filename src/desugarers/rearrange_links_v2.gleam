// import blamedlines.{type Blame, Blame}
// import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
// import vxml.{type VXML, BlamedAttribute, BlamedContent, T, V}
import xmlm

type PatternToken {
  Word(String)    // (does not contain whitespace)
  Space
  ContentVar(Int)
  A(
    String,       // tag name ( for now it's either a or InChapterLink )
    String,       // classes
    Int,          // href variable
    LinkPattern,  // the List(PatternToken) inside of the a-tag
  )
  EndT
  StartT
}

type LinkPattern =
  List(PatternToken)

fn nodemap_factory(_inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  // nodemap(_, inner)
  fn(vxml){vxml}
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_no_error_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

type PatternTokenClassification {
  TextPatternToken
  NonTextPatternToken
  StartTToken
  EndTToken
}

type PatternTokenTransition {
  TextToNonText
  NonTextToText
  NoTransition
}

fn classify_pattern_token(token: PatternToken) -> PatternTokenClassification {
  case token {
    Space | Word(_) -> TextPatternToken
    ContentVar(_) | A(_, _, _, _) -> NonTextPatternToken
    StartT -> StartTToken
    EndT -> EndTToken
  }
}

fn check_pattern_token_text_non_text_consistency(
  tokens: LinkPattern,
)  -> LinkPattern {
  list.fold(
    tokens,
    None,
    fn (acc, token) {
      case acc {
        None -> Some(classify_pattern_token(token))
        Some(prev_classification) -> {
          let next_classification = classify_pattern_token(token)
          case prev_classification, next_classification {
            TextPatternToken, NonTextPatternToken -> panic as "Text went straight to NonText"
            NonTextPatternToken, TextPatternToken -> panic as "NonText went straight to Text"
            StartTToken, NonTextPatternToken -> panic as "start not followed by end or text"
            EndTToken, TextPatternToken -> panic as "end not followed by start or non-text"
            TextPatternToken, StartTToken -> panic as "text followed by start"
            NonTextPatternToken, EndTToken -> panic as "non-text followed by end"
            StartTToken, StartTToken -> panic as "start followed by start"
            EndTToken, EndTToken -> panic as "end followed by end"
            _, _ -> Some(prev_classification)
          }
        }
      }
    }
  )
  tokens
}

fn transition_kind(from: PatternToken, to: PatternToken) -> PatternTokenTransition {
  case classify_pattern_token(from), classify_pattern_token(to) {
    TextPatternToken, NonTextPatternToken -> TextToNonText
    NonTextPatternToken, TextPatternToken -> NonTextToText
    TextPatternToken, TextPatternToken -> NoTransition
    NonTextPatternToken, NonTextPatternToken -> NoTransition
    _, _ -> panic as "not expecting StartT or EndT tokens in this function"
  }
}

fn insert_start_t_end_t_into_link_pattern(
  pattern_tokens: LinkPattern
) -> LinkPattern {
  list.fold(
    pattern_tokens,
    [],
    fn(acc,  token) {
      case acc {
        [] -> [token, ..acc]
        [last, ..] -> case transition_kind(last, token) {
          TextToNonText -> [token, EndT, ..acc]
          NonTextToText -> [token, StartT, ..acc]
          NoTransition -> [token, ..acc]
        }
      }
    }
  )
}

fn make_link_pattern_2_substitutable_for_link_pattern_1(
  lp1: LinkPattern,
  lp2: LinkPattern,
)

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

fn word_to_optional_tokens(word: String) -> Option(LinkPattern) {
  case word {
    "" -> None
    _ -> Some([Word(word)])
  }
}

fn split_variables(words: List(String), re: regexp.Regexp) -> List(Option(LinkPattern)) {
  words
  |> list.map(fn(word) {
    case regexp.check(re, word) {
      False -> word_to_optional_tokens(word)
      True -> {
        // example of splits for _1_._2_ ==> ["", "_1_", ".", "_2_", ""]
        regexp.split(re, word)
        |> list.index_map(
          fn(x, i) {
            case i % 2 == 0 {
              True -> Word(x)
              False -> {
                let assert True = string.starts_with(x, "_") && string.ends_with(x, "_") && string.length(x) > 2
                let assert Ok(x) = x |> string.drop_end(1) |> string.drop_start(1) |> int.parse
                ContentVar(x)
              }
            }
          }
        )
        |> Some
      }
    }
  })
}

fn text_to_link_pattern(content: String, re: regexp.Regexp) -> Result(LinkPattern, DesugaringError) {
  content
  |> string.split(" ")
  |> split_variables(re)
  |> list.intersperse(Some([Space]))
  |> option.values
  |> list.flatten
  |> check_pattern_token_text_non_text_consistency
  |> Ok
}

fn tag_to_link_pattern(
  xmlm_tag: xmlm.Tag,
  children: List(Result(LinkPattern, DesugaringError)),
) {
  use tag_content_patterns <- result.try(children |> result.all)

  let tag_content_patterns = tag_content_patterns |> list.flatten

  use <- infra.on_true_on_false(
    xmlm_tag_name(xmlm_tag) == "root",
    Ok(tag_content_patterns),
  )

  use href_attribute <- result.try(
    xmlm_tag.attributes
    |> list.find(xmlm_attribute_equals(_, "href"))
    |> result.map_error(
      fn(_) {DesugaringError(infra.no_blame, "<a> pattern tag missing 'href' attribute")}
    ),
  )

  let xmlm.Attribute(_, value) = href_attribute

  use value <- result.try(
    int.parse(value)
    |> result.map_error(fn(_) {
      DesugaringError(infra.no_blame, "<a> pattern 'href' attribute does not parse to an int")
    }),
  )

  let class_attribute =
    xmlm_tag.attributes
    |> list.find(xmlm_attribute_equals(_, "class"))

  let classes = case class_attribute {
    Ok(x) -> {
      let xmlm.Attribute(_, value) = x
      value
    }
    Error(_) -> ""
  }

  Ok([A(xmlm_tag_name(xmlm_tag), classes, value, tag_content_patterns)])
}

fn extra_string_to_link_pattern(
  s: String,
  re: regexp.Regexp,
) -> Result(LinkPattern, DesugaringError) {
  case
    xmlm.document_tree(
      xmlm.from_string(s),
      tag_to_link_pattern,
      text_to_link_pattern(_, re),
    )
  {
    Ok(#(_, pattern, _)) -> pattern
    Error(input_error) ->
      Error(DesugaringError(infra.blame_us(""), ins(input_error)))
  }
}

fn make_sure_attributes_are_quoted(input: String, re: regexp.Regexp) -> String {
  regexp.match_map(re, input, fn(match: regexp.Match) {
    case match.submatches {
      [Some(key), Some(value)] -> key <> "=\"" <> value <> "\""
      _ -> match.content
    }
  })
}

fn string_pair_to_link_pattern_pair(string_pair: #(String, String)) -> Result(#(LinkPattern, LinkPattern), DesugaringError) {
  let #(s1, s2) = string_pair
  let assert Ok(re1) = regexp.compile("([a-zA-Z0-9-]+)=([^\"'][^ >]*)", regexp.Options(True, True))
  let assert Ok(re2) = regexp.from_string("(_[0-9]+_)")

  use pattern1 <- result.try(
    { "<root>" <> s1 <> "</root>" }
    |> make_sure_attributes_are_quoted(re1)
    |> extra_string_to_link_pattern(re2)
  )

  use pattern2 <- result.try(
    { "<root>" <> s2 <> "</root>" }
    |> make_sure_attributes_are_quoted(re1)
    |> extra_string_to_link_pattern(re2)
  )

  Ok(#(pattern1, pattern2))
}

fn get_content_vars(
  pattern2: LinkPattern,
) -> List(Int) {
  list.map(pattern2, fn(token) {
    case token {
      ContentVar(var) -> [var]
      A(_, _, _, sub_pattern) -> get_content_vars(sub_pattern)
      _ -> []
    }
  })
  |> list.flatten
}

fn get_href_vars(
  pattern2: LinkPattern,
) -> List(Int) {
  list.map(pattern2, fn(token) {
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
  let vars = get_href_vars(pattern2)
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
  let vars = get_href_vars(pattern1)
  case infra.get_duplicate(vars) {
    None -> Ok(vars)
    Some(int) -> Error(int)
  }
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  use #(pattern1, pattern2) <- result.try(string_pair_to_link_pattern_pair(param))

  use unique_href_vars <- result.try(
    collect_unique_href_vars(pattern1)
    |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Source pattern " <> param.0 <>" has duplicate declaration of href variable: " <> ins(var) ) })
  )

  use unique_content_vars <- result.try(
    collect_unique_content_vars(pattern1)
    |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Source pattern " <> param.0 <>" has duplicate declaration of content variable: " <> ins(var)) })
  )

  use _ <- result.try(
    check_each_href_var_is_sourced(pattern2, unique_href_vars)
    |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Target pattern " <> param.1 <> " has a declaration of unsourced href variable: " <> ins(var)) })
  )

  use _ <- result.try(
    check_each_content_var_is_sourced(pattern2, unique_content_vars)
    |> result.map_error(fn(var){ DesugaringError(infra.blame_us("..."), "Target pattern " <> param.1 <> " has a declaration of unsourced content variable: " <> ins(var)) })
  )

  Ok(#(pattern1, pattern2))
}

type Param = #(String,   String)
//             ↖         ↖
//             source    target
//             pattern   pattern

type InnerParam = #(LinkPattern, LinkPattern)

const name = "rearrange_links_v2"
const constructor = rearrange_links_v2

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// matches appearance of first String while 
/// considering (x) as a variable and replaces it 
/// with the second String (x) can be used in second
/// String to use the variable from first String
pub fn rearrange_links_v2(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// matches appearance of first String while 
/// considering (x) as a variable and replaces it 
/// with the second String (x) can be used in second
/// String to use the variable from first String
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
