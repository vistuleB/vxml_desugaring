import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedContent, T, V}

fn substitute_blames_in(node: VXML, new_blame: Blame) -> VXML {
  let assert T(_, blamed_contents) = node
  T(
    new_blame,
    list.map(blamed_contents, fn(blamed_content) {
      BlamedContent(new_blame, blamed_content.content)
    }),
  )
}

fn last_line_concatenate_with_first_line(node1: VXML, node2: VXML) -> VXML {
  let assert T(blame1, lines1) = node1
  let assert T(_, lines2) = node2

  let assert [BlamedContent(blame_last, content_last), ..other_lines1] =
    lines1 |> list.reverse
  let assert [BlamedContent(_, content_first), ..other_lines2] = lines2

  T(
    blame1,
    list.flatten([
      other_lines1 |> list.reverse,
      [BlamedContent(blame_last, content_last <> content_first)],
      other_lines2,
    ]),
  )
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      case dict.get(inner, tag) {
        Error(Nil) -> Ok(node)
        Ok(#(v1, v2)) -> {
          let new_children =
            list.map(children, fn(child) {
              case child {
                V(_, _, _, _) -> child
                T(blame, _) -> {
                  substitute_blames_in(v1, blame)
                  |> last_line_concatenate_with_first_line(child)
                  |> last_line_concatenate_with_first_line(substitute_blames_in(
                    v2,
                    blame,
                  ))
                }
              }
            })
          Ok(V(blame, tag, attrs, new_children))
        }
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> list.map(fn(tuple) {
    let #(t1, t2, tag) = tuple
    let contents1 = string.split(t1, "\n")
    let contents2 = string.split(t2, "\n")
    let v1 =
      T(
        infra.no_blame,
        list.map(contents1, fn(content) {
          BlamedContent(infra.no_blame, content)
        }),
      )
    let v2 =
      T(
        infra.no_blame,
        list.map(contents2, fn(content) {
          BlamedContent(infra.no_blame, content)
        }),
      )
    #(tag, #(v1, v2))
  })
  |> dict.from_list
  |> Ok
}

type Param =
  List(#(String, String, String))
//       ↖       ↖       ↖
//       text    text    parent
//       to      to      tag
//       prepend append

type InnerParam =
  Dict(String, #(VXML, VXML))

pub const desugarer_name = "prepend_append_to_text_children_of"
pub const desugarer_pipe = prepend_append_to_text_children_of

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// prepends and appends text to all text children of specified tags
pub fn prepend_append_to_text_children_of(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// prepends and appends text to all text children of specified tags
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}