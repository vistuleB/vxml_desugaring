import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe } as infra
import vxml.{ type VXML, BlamedContent, T, V }

fn param_transform(vxml: VXML, param: Param) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(param, tag) {
        Ok(text) -> {
          let contents = string.split(text, "\n")
          let new_text_node =
            T(
              blame,
              list.map(
                contents,
                fn (content) { BlamedContent(blame, content) }
              )
            )
          Ok(
            V(blame, tag, attrs, [new_text_node, ..children])
          )
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(param: Param) -> infra.NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

type Param =
  Dict(String, String)

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
    desugarer: case infra.dict_from_list_with_desugaring_error(extra) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
