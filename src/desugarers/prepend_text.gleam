import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{ type VXML, BlamedContent, T, V}

fn param_transform(vxml: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(param, tag) {
        Ok(text) -> {
          let text = text |> string.join(" ")

          use first_child <- infra.on_error_on_ok(
            over: list.first(children),
            with_on_error: fn(_){ 
              let new_text_node = T(blame, [BlamedContent(blame, text)])

              Ok(V(blame, tag, attrs, [new_text_node])) 
            }
          )
          let assert [_, ..rest_children] = children

          let new_text_node = case first_child {
            V(b, _, _, _) -> {
              T(b, [BlamedContent(b, text)])
            }
            T(b, contents) -> {
              T(b, list.prepend(contents, BlamedContent(b, text)))
            }
          }
          Ok(V(blame, tag, attrs, [new_text_node, ..rest_children])) 
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn extra_to_param(extra: Extra) -> Param {
  extra |> infra.aggregate_on_first
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Param =
  Dict(String, List(String))

type Extra =
  List(#(String, String))
//        tag     text

pub fn prepend_text(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "prepend_text",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra |> extra_to_param),
  )
}
