import gleam/list
import gleam/option.{None}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
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

pub fn replace_multiple_spaces_by_one() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "replace_multiple_spaces_by_one",
      None,
      "...",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
