import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, contents) ->{
      use first_non_empty <- infra.on_error_on_ok(
        over: list.find(contents, fn(blamed_content) {
          !{ string.is_empty(blamed_content.content) }
        }),
        with_on_error: fn(_){ Ok(vxml) }
      )
      Ok(T(first_non_empty.blame, contents))
      }
    _ -> Ok(vxml)
  }
}

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub fn reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
