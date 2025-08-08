import blamedlines.{Blame}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

const desugarer_blame = Blame("python_prompt_code_block", 0, 0, [])

type PythonPromptChunk {
  PromptLine(BlamedContent)
  OkResponseLines(List(BlamedContent))
  ErrorResponseLines(List(BlamedContent))
}

fn python_prompt_chunk_to_vxmls(
  chunk: PythonPromptChunk,
) -> List(VXML) {
  case chunk {
    PromptLine(bc) -> {
      [
        V(
          desugarer_blame,
          "span",
          [BlamedAttribute(desugarer_blame, "class", "python-prompt-carets")],
          [
            T(
              bc.blame,
              [BlamedContent(bc.blame, ">>>")]
            )
          ]
        ),
        V(
          desugarer_blame,
          "span",
          [BlamedAttribute(desugarer_blame, "class", "python-prompt-content")],
          [
            T(
              infra.advance(bc.blame, 3),
              [BlamedContent(infra.advance(bc.blame, 3), bc.content |> string.drop_start(3))]
            )
          ]
        )
      ]
    }
    OkResponseLines(lines) -> {
      [
        V(
          desugarer_blame,
          "span",
          [BlamedAttribute(desugarer_blame, "class", "python-prompt-ok-response")],
          [
            T(
              lines |> infra.lines_first_blame,
              lines
            )
          ]
        )
      ]
    }
    ErrorResponseLines(lines) -> {
      [
        V(
          desugarer_blame,
          "span",
          [BlamedAttribute(desugarer_blame, "class", "python-prompt-error-response")],
          [
            T(
              lines |> infra.lines_first_blame,
              lines
            )
          ]
        )
      ]
    }
  }
}

fn process_python_prompt_lines(lines: List(BlamedContent)) -> List(PythonPromptChunk) {
  lines
  |> infra.either_or_misceginator(fn(bc) {
    string.starts_with(bc.content, ">>>")
  })
  |> infra.regroup_ors_no_empty_lists
  |> list.map(fn(either_bc_or_list_bc) {
    case either_bc_or_list_bc {
      infra.Either(bc) -> PromptLine(bc)
      infra.Or(list_bc) -> case infra.lines_contain(list_bc, "SyntaxError:") {
        True -> ErrorResponseLines(list_bc)
        False -> OkResponseLines(list_bc)
      }
    }
  })
}

fn nodemap(
  vxml: VXML,
) -> VXML {
  case vxml {
    V(blame, "CodeBlock", _, [T(_, lines)]) -> {
      // check if this CodeBlock has language=python-prompt
      case infra.v_has_key_value(vxml, "language", "python-prompt") {
        True -> {

          // process the lines into chunks
          let chunks = process_python_prompt_lines(lines)

          // convert chunks to VXML lists
          let list_list_vxmls =
            chunks
            |> list.map(python_prompt_chunk_to_vxmls)

          // add newlines between chunks
          let children =
            list_list_vxmls
            |> list.intersperse([
              T(
                desugarer_blame,
                [
                  BlamedContent(desugarer_blame, ""),
                  BlamedContent(desugarer_blame, ""),
                ]
              )
            ])
            |> list.flatten

          // create a pre element with python-prompt class
          V(
            blame,
            "pre",
            [BlamedAttribute(desugarer_blame, "class", "python-prompt")],
            children,
          )
        }

        _ -> vxml  // not a python-prompt CodeBlock, return unchanged
      }
    }
    _ -> vxml  // not a CodeBlock, return unchanged
  }
}

fn nodemap_factory() -> n2t.OneToOneNoErrorNodeMap {
  fn(vxml) { nodemap(vxml) }
}

fn transform_factory() -> DesugarerTransform {
  nodemap_factory()
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform
}

const name = "python_prompt_code_block"
const constructor = python_prompt_code_block

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Processes CodeBlock elements with language=python-prompt
/// and converts them to pre elements with proper span
/// highlighting for prompts, responses, and errors
pub fn python_prompt_code_block() -> Desugarer {
  Desugarer(
    name,
    option.None,
    option.None,
    "
/// Processes CodeBlock elements with language=python-prompt
/// and converts them to pre elements with proper span
/// highlighting for prompts, responses, and errors
    ",
    transform_factory()
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Nil)) {
  [
    infra.AssertiveTestData(
      param: Nil,
      source: "
                <> CodeBlock
                  language=python-prompt
                  <>
                    \">>> (6 + 8) * 3\"
                    \"42\"
                    \">>> (2 * 3))\"
                    \"  File \\\"<stdin>\\\", line 1\"
                    \"    (2 * 3))\"
                    \"           ^\"
                    \"SyntaxError: unmatched ')'\"
                ",
      expected: "
                <> pre
                  class=python-prompt
                  <> span
                    class=python-prompt-carets
                    <>
                      \">>>\"
                  <> span
                    class=python-prompt-content
                    <>
                      \" (6 + 8) * 3\"
                  <>
                    \"\"
                    \"\"
                  <> span
                    class=python-prompt-ok-response
                    <>
                      \"42\"
                  <>
                    \"\"
                    \"\"
                  <> span
                    class=python-prompt-carets
                    <>
                      \">>>\"
                  <> span
                    class=python-prompt-content
                    <>
                      \" (2 * 3))\"
                  <>
                    \"\"
                    \"\"
                  <> span
                    class=python-prompt-error-response
                    <>
                      \"  File \\\"<stdin>\\\", line 1\"
                      \"    (2 * 3))\"
                      \"           ^\"
                      \"SyntaxError: unmatched ')'\"
                "
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), fn(_) { constructor() })
}
