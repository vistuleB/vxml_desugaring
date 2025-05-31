import gleam/list
import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(blame, tag, _, children) -> {
      let #(del_tag, opening, closing) = param
      case del_tag == tag {
        True -> {
          let opening = V(blame, opening, [], [])
          let closing = V(blame, closing, [], [])
          Ok(list.flatten([[opening], children, [closing]]))
        }
        False -> Ok([vxml])
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String, String)

type InnerParam = Param

pub fn replace_text_parent_by_text_bookends(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "replace_text_parent_by_text_bookends",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
