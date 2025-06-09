import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{ type VXML, BlamedContent, T, V }

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(inner, tag) {
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  infra.dict_from_list_with_desugaring_error(param)
}

type Param =
  List(#(String, String))
//       ↖      ↖
//       tag    text

type InnerParam =
  Dict(String, String)

/// prepends text to the beginning of specified tags
pub fn prepend_text(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "prepend_text",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// prepends text to the beginning of specified tags
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}