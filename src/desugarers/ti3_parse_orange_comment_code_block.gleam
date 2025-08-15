import blamedlines.{Blame}
import gleam/list
import gleam/option.{None}
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

const desugarer_blame = Blame("ti3_parse_orange_comment", 0, 0, [])
const t_1_empty_line = T(desugarer_blame, [BlamedContent(desugarer_blame, "")])
const orange = V(desugarer_blame, "span", [BlamedAttribute(desugarer_blame, "class", "orange-comment")], [])

fn t_1_line(line: BlamedContent) -> VXML {
  T(line.blame, [line])
}

fn elements_for_line(line: BlamedContent) -> List(VXML) {
  case string.split_once(line.content, "//") {
    Error(_) -> [t_1_line(line)]
    Ok(#(before, after)) -> {
      let after_blame = infra.advance(line.blame, string.length(before) + 2)
      let before = t_1_line(BlamedContent(line.blame, before))
      let orange = orange |> infra.prepend_child(t_1_line(BlamedContent(after_blame, after)))
      [before, orange, t_1_empty_line]
    }
  }
}

fn process_orange_comment_lines(
  lines: List(BlamedContent),
) -> List(VXML) {
  lines
  |> list.fold([], fn(acc, line) { infra.pour(elements_for_line(line), acc)})
  |> list.reverse
  |> infra.plain_concatenation_in_list
}

fn nodemap(
  vxml: VXML,
) -> VXML {
  case vxml {
    V(blame, "CodeBlock", _, [T(_, lines)]) -> {
      case infra.v_has_key_value(vxml, "language", "orange-comment") {
        True ->
          V(
            blame,
            "pre",
            [],
            process_orange_comment_lines(lines, ),
          )
        _ -> vxml
      }
    }
    _ -> vxml
  }
}

fn nodemap_factory(_: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform
}

fn param_to_inner_param(_param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(Nil)
}

const name = "ti3_parse_orange_comment_code_block"
const constructor = ti3_parse_orange_comment_code_block

type Param = Nil
type InnerParam = Nil

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Processes CodeBlock elements with language=orange-comment
/// and converts them to pre elements with orange
/// comment highlighting for text after // markers
pub fn ti3_parse_orange_comment_code_block() -> Desugarer {
  Desugarer(
    name,
    None,
    None,
    "
/// Processes CodeBlock elements with language=orange-comment
/// and converts them to pre elements with orange
/// comment highlighting for text after // markers
    ",
    case param_to_inner_param(Nil) {
      Error(e) -> fn(_) { Error(e) }
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
                <> CodeBlock
                  language=orange-comment
                  <>
                    \"def mult(t,x):\"
                    \"    temp = 0 //= zero(x)\"
                    \"    for i in range(t):\"
                    \"        temp = add(temp,x) //= Comp(add, p_0, p2) (temp,i,x)\"
                    \"    return temp\"
                ",
      expected: "
                <> pre
                  <>
                    \"def mult(t,x):\"
                    \"    temp = 0 \"
                  <> span
                    class=orange-comment
                    <>
                      \"= zero(x)\"
                  <>
                    \"\"
                    \"    for i in range(t):\"
                    \"        temp = add(temp,x) \"
                  <> span
                    class=orange-comment
                    <>
                      \"= Comp(add, p_0, p2) (temp,i,x)\"
                  <>
                    \"\"
                    \"    return temp\"
                "
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_no_param(name, assertive_tests_data(), constructor)
}
