import blamedlines.{Blame}
import gleam/list
import gleam/option.{None}
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

const desugarer_blame = Blame("ti3_parse_orange_comment_code_block", 0, 0, [])

fn process_line_for_orange_comments(line: BlamedContent, acc: List(VXML)) -> List(VXML) {
  case string.split_once(line.content, "//") {
    Error(_) -> [T(line.blame, [line]), ..acc]

    Ok(#(before, after)) -> {
      let before_blame = line.blame
      let after_blame = infra.advance(line.blame, string.length(before) + 2)

      // create the three elements in reverse order (since we're prepending to acc)
      let newline_element = T(desugarer_blame, [BlamedContent(desugarer_blame, "")])
      let orange_comment_element = V(
        desugarer_blame,
        "span",
        [BlamedAttribute(desugarer_blame, "class", "orange-comment")],
        [T(after_blame, [BlamedContent(after_blame, after)])]
      )
      let before_element = T(before_blame, [BlamedContent(before_blame, before)])

      [newline_element, orange_comment_element, before_element, ..acc]
    }
  }
}

fn process_orange_comment_lines(lines: List(BlamedContent)) -> List(VXML) {
  lines
  |> list.fold([], fn(acc, line) { process_line_for_orange_comments(line, acc) })
  |> list.reverse
  |> infra.plain_concatenation_in_list
}

fn nodemap(
  vxml: VXML,
  _inner: InnerParam,
) -> VXML {
  case vxml {
    V(blame, "CodeBlock", _, [T(_, lines)]) -> {
      // check if this CodeBlock has language=orange-comment
      case infra.v_has_key_value(vxml, "language", "orange-comment") {
        True -> {
          // process the lines for orange comments
          let processed_children = process_orange_comment_lines(lines)

          V(
            blame,
            "pre",
            [],
            processed_children,
          )
        }
        _ -> vxml  // not an orange-comment CodeBlock, return unchanged
      }
    }
    _ -> vxml  // not a CodeBlock, return unchanged
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform
}

fn param_to_inner_param(_param: Param) -> Result(InnerParam, DesugaringError) {
  T(
    desugarer_blame,
    [
      BlamedContent(desugarer_blame, ""),
      BlamedContent(desugarer_blame, ""),
    ]
  )
  |> Ok
}

const name = "ti3_parse_orange_comment_code_block"
const constructor = ti3_parse_orange_comment_code_block

type Param = Nil
type InnerParam = VXML

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
