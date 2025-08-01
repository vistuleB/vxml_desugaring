import blamedlines.{type Blame}
import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, V, T, BlamedContent}

fn detokenize_in_list(
  children: List(VXML),
  accumulated_contents: List(vxml.BlamedContent),
  accumulated_nodes: List(VXML)
) -> List(VXML) {
  let append_word_to_accumlated_contents = fn(blame: Blame, word: String) -> List(vxml.BlamedContent) {
    case accumulated_contents {
      [first, ..rest] -> [BlamedContent(first.blame, first.content <> word), ..rest]
      _ -> [BlamedContent(blame, word)]
    }
  }

  case children {
    [] -> {
      accumulated_nodes |> list.reverse |> infra.last_to_first_concatenation
    }

    [first, ..rest] -> {
      case first {
        V(blame, "__StartAtomizedT", _, _) -> {
          let assert [] = accumulated_contents
          let accumulated_contents = [BlamedContent(blame, "")]
          detokenize_in_list(rest, accumulated_contents, accumulated_nodes)
        }
        
        V(blame, "__OneWord", attributes, _) -> {
          let assert [BlamedAttribute(_, "val", word)] = attributes
          let accumulated_contents = append_word_to_accumlated_contents(blame, word)
          detokenize_in_list(rest, accumulated_contents, accumulated_nodes)
        }

        V(blame, "__OneSpace", _, _) -> {
          let accumulated_contents = append_word_to_accumlated_contents(blame, " ")
          detokenize_in_list(rest, accumulated_contents, accumulated_nodes)
        }

        V(blame, "__OneNewLine", _, _) -> {
          let accumulated_contents = case accumulated_contents {
            [] -> [BlamedContent(blame, ""), BlamedContent(blame, "")]
            _ -> [BlamedContent(blame, ""), ..accumulated_contents]
          }
          detokenize_in_list(rest, accumulated_contents, accumulated_nodes)
        }
        V(blame, "__EndAtomizedT", _, _) -> {
          let accumulated_contents = append_word_to_accumlated_contents(blame, "")
          let t = T(blame, accumulated_contents |> list.reverse)
          detokenize_in_list(rest, [], [t, ..accumulated_nodes])
        }
        _ -> {
          let assert True = list.is_empty(accumulated_contents)
          detokenize_in_list(rest, [], [first, ..accumulated_nodes])
        }
      
      }
    }
  }
}

fn nodemap(
  vxml: VXML,
  _: InnerParam,
) -> VXML {
  case vxml {
    V(_, _, _, children) -> {
      let children = detokenize_in_list(children, [], [])
      V(..vxml, children: children)
    }
    _ -> vxml
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

type Param = Nil
type InnerParam = Param

const name = "detokenize_all"
const constructor = detokenize_all

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// 
pub fn detokenize_all() -> Desugarer {
  Desugarer(
    name,
    option.None,
    option.None,
    "
/// 
    ",
    case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestDataNoParam) {
  [
    infra.AssertiveTestDataNoParam(
      source: "
            <> testing
              <> bb
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
                <> inside
                  <>
                    \"some text\"
      ",
      expected: "
          <> testing
            <> bb
              <> 
                \"first line\"
                \"second line\"

              <> inside
                <>
                  \"some text\"
      ",
    ),
    infra.AssertiveTestDataNoParam(
      source: "
            <> testing
              <> bb
                <> __OneWord
                  val=first
                <> __OneSpace
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __EndAtomizedT
      ",
      expected: "
            <> testing
              <> bb
                <> 
                  \"first  line\"
      ",
    ),
    infra.AssertiveTestDataNoParam(
      source: "
            <> testing
              <> bb
                <> __OneWord
                  val=first
                <> __OneSpace
                <> __OneNewLine
                <> __OneSpace
                <> __OneWord
                  val=line
                <> __EndAtomizedT
      ",
      expected: "
            <> testing
              <> bb
                <> 
                  \"first \"
                  \" line\"
      ",
    ),
    infra.AssertiveTestDataNoParam(
      source: "
            <> testing
              <> bb
                <> __OneWord
                  val=
                <> __OneNewLine
                <> __OneWord
                  val=
                <> __EndAtomizedT
      ",
      expected: "
            <> testing
              <> bb
                <> 
                  \"\"
                  \"\"
      ",
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_no_param(name, assertive_tests_data(), constructor)
}