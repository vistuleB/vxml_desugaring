import blamedlines.{type Blame}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, V, T}

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

fn start_node(blame: Blame) {
  V(blame, "__StartAtomizedT", [], [])
}

fn end_node(blame: Blame) {
  V(blame, "__EndAtomizedT", [], [])
}

/// since number of spaces between words is important, we can't use string.split and list.intersperse combo
fn split_words_by_spaces(blame: Blame, str: String, word: String, spaces: String) -> List(VXML) {
  let word_node = case word {
    "" -> []
    _ -> [word_to_node(blame, word)]
  }
  let spaces_nodes = list.repeat(space_node(blame), string.length(spaces))

  case string.first(str) {
    Ok(" ") ->
      list.flatten([  
        word_node,
        split_words_by_spaces(blame, string.drop_start(str, 1), "", spaces <> " ")
      ])
    Ok(char) ->
      list.flatten([
        spaces_nodes,
        split_words_by_spaces(blame, string.drop_start(str, 1), word <> char, "")
      ])
    Error(_) ->
      list.flatten([
        spaces_nodes,
        word_node,
      ])
  }
}

fn tokenize_t(vxml: VXML) -> List(VXML) {
  let assert T(blame, blamed_contents) = vxml
  blamed_contents
  |> list.index_map(fn(blamed_content, i) {
    blamed_content.content
    |> split_words_by_spaces(blamed_content.blame, _, "", "")
    |> fn (tokens) {
        case tokens {
          [] -> [word_to_node(blamed_content.blame, "")]
          _ -> tokens
        }
      }
    |> fn (tokens) {
        case i > 0 {
          False -> tokens |> list.prepend(start_node(blamed_content.blame))
          True -> tokens |> list.prepend(line_node(blamed_content.blame))
        }
      }
    })
  |> list.flatten
  |> list.append([end_node(blame)])
}

fn tokenize_if_t(vxml: VXML) -> List(VXML) {
  case vxml {
    T(_, _) -> tokenize_t(vxml)
    _ -> [vxml]
  }
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    T(_, _) -> vxml
    V(_, _, _, _) -> case inner(vxml) {
      False -> vxml
      True -> V(
        ..vxml,
        children: list.map(
          vxml.children,
          tokenize_if_t,
        ) |> list.flatten
      )
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = fn(VXML) -> Bool
type InnerParam = Param

const name = "tokenize_text_children"
const constructor = tokenize_text_children

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// 
pub fn tokenize_text_children(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// 
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
  let test_param = fn(vxml) { 
    let assert V(_, t, _, _) = vxml
    t == "a"
  }
  [
    infra.AssertiveTestData(
      param: test_param,
      source: "
            <> testing
              <> a
                <> 
                  \"first line\"
                  \"second line\"
                <>
                  \"third line\"

                <> inside
                  <>
                    \"some text\"
      ",
      expected: "
            <> testing
              <> a
                <> __StartAtomizedT
                <> __OneWord
                  val=first
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __OneNewLine
                <> __OneWord
                  val=second
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __EndAtomizedT
                <> __StartAtomizedT
                <> __OneWord
                  val=third
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __EndAtomizedT
                <> inside
                  <>
                    \"some text\"
      ",
    ),
    infra.AssertiveTestData(
      param: test_param,
      source: "
            <> testing
              <> a
                <> 
                  \"first  line\"
                  \"second  \"
                  \"   line\"
      ",
      expected: "
            <> testing
              <> a
                <> __StartAtomizedT
                <> __OneWord
                  val=first
                <> __OneSpace
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __OneNewLine
                <> __OneWord
                  val=second
                <> __OneSpace
                <> __OneSpace
                <> __OneNewLine
                <> __OneSpace
                <> __OneSpace
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __EndAtomizedT
      ",
    ),
    infra.AssertiveTestData(
      param: test_param,
      source: "
            <> testing
              <> a
                <> 
                  \"\"
                  \"\"
      ",
      expected: "
            <> testing
              <> a
                <> __StartAtomizedT
                <> __OneWord
                  val=
                <> __OneNewLine
                <> __OneWord
                  val=
                <> __EndAtomizedT
      ",
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}