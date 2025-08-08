import blamedlines.{type Blame}
import gleam/list
import gleam/option.{Some,None}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V}

type PythonPromptChunk {
  PromptLine(BlamedContent)
  OkResponseLines(List(BlamedContent))
  ErrorResponseLines(List(BlamedContent))
}

fn python_prompt_chunk_to_vxmls(
  chunk: PythonPromptChunk,
  desugarer_blame: Blame,
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
  |> infra.regroup_ors
  |> list.map(fn(either_bc_or_list_bc) {
    case either_bc_or_list_bc {
      infra.Either(bc) -> PromptLine(bc)
      infra.Or(list_bc) -> case infra.lines_contain(list_bc, "SyntaxError:") {
        True -> ErrorResponseLines(list_bc)
        False -> OkResponseLines(list_bc)
      }
    }
  })
  |> list.filter(fn(chunk) {
    case chunk {
      PromptLine(_) -> True
      OkResponseLines([]) -> False
      ErrorResponseLines([]) -> False
      _ -> True
    }
  })
}

fn nodemap(
  vxml: VXML,
  _inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(blame, "CodeBlock", _attributes, [T(_, lines)]) -> {
      // check if this CodeBlock has language=python-prompt
      case infra.v_attribute_with_key(vxml, "language") {
        Some(lang_attr) if lang_attr.value == "python-prompt" -> {
          let desugarer_blame = infra.blame_us("python_prompt_code_block")

          // process the lines into chunks
          let chunks = process_python_prompt_lines(lines)

          // convert chunks to VXML lists
          let list_list_vxmls =
            chunks
            |> list.map(python_prompt_chunk_to_vxmls(_, desugarer_blame))

          // add newlines between chunks
          let children =
            list_list_vxmls
            |> list.intersperse([
              T(
                desugarer_blame,
                [
                  BlamedContent(desugarer_blame, ""),
                  BlamedContent(desugarer_blame, "")
                ]
              )
            ])
            |> list.flatten

          // create a pre element with python-prompt class
          Ok([
            V(
              blame,
              "pre",
              [BlamedAttribute(desugarer_blame, "class", "python-prompt")],
              children
            )
          ])
        }
        _ -> Ok([vxml])  // not a python-prompt CodeBlock, return unchanged
      }
    }
    _ -> Ok([vxml])  // not a CodeBlock, return unchanged
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToManyNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_many_nodemap_2_desugarer_transform
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Param

const name = "python_prompt_code_block"
const constructor = python_prompt_code_block

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Processes CodeBlock elements with language=python-prompt
/// and converts them to pre elements with proper span
/// highlighting for prompts, responses, and errors
pub fn python_prompt_code_block(param: Param) -> Desugarer {
  Desugarer(
    name,
    Some(ins(param)),
    None,
    "
/// Processes CodeBlock elements with language=python-prompt
/// and converts them to pre elements with proper span
/// highlighting for prompts, responses, and errors
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
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
