import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(blame, lines) -> {
      case lines {
        [] -> Ok(vxml)
        [first, ..] -> {
          case first.content |> string.starts_with(" ") {
            True -> {
              let new_line = " " <> first.content |> string.trim_start()
              Ok(
                T(blame, [
                  vxml.BlamedContent(first.blame, new_line),
                  ..list.drop(lines, 1)
                ]),
              )
            }
            False -> Ok(vxml)
          }
        }
      }
    }
    _ -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// replaces multiple consecutive spaces with a single space
pub fn replace_multiple_spaces_by_one() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "replace_multiple_spaces_by_one",
      stringified_param: option.None,
      general_description: "
/// replaces multiple consecutive spaces with a single space
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
