import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
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

fn transform_factory() -> infra.NodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "reassign_text_node_blame_to_blame_of_first_nonempty_line_in_text_node",
      option.None,
      "...",
    ),
    desugarer: desugarer_factory(),
  )
}


