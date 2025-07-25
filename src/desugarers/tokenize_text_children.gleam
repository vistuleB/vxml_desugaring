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

fn end_node(blame: Blame) {
  V(blame, "__EndAtomizedT", [], [])
}

fn tokenize_t(vxml: VXML) -> List(VXML) {
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
  [
    infra.AssertiveTestData(
      param: fn(vxml) { 
        let assert V(_, t, _, _) = vxml
        t == "a"
      },
      source: "
            <> testing
              <> a
                <> 
                  \"first line\"
                  \"second line\"

                <> inside
                  <>
                    \"some text\"
      ",
      expected: "
            <> testing
              <> a
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
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}