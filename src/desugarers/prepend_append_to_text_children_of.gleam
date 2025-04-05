import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, BlamedContent, T, V}

const ins = string.inspect

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

fn param_transform(node: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      case dict.get(param, tag) {
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

fn extra_to_param(extra: Extra) -> Param {
  extra
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
}

type Param =
  Dict(String, #(VXML, VXML))

//***********************************
// - String: text to prepend
// - String: text to append
// - String: parent tag
type Extra =
  List(#(String, String, String))

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

pub fn prepend_append_to_text_children_of(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "prepend_append_to_text_children_of",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra |> extra_to_param),
  )
}
