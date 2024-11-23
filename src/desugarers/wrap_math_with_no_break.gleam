import gleam/option
import gleam/result
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError, depth_first_node_to_node_desugarer,
}
import vxml_parser.{type VXML, T, V}

fn check_if_next_is_line_that_starts_with_none_space(
  rest: List(VXML),
) -> Result(VXML, String) {
  case rest {
    [] -> Error("No")
    [first, ..] -> {
      case first {
        V(_, _, _, _) -> Error("No")
        T(_, a) -> {
          case a {
            [] -> Error("No")
            [f, ..] -> {
              case !{ string.starts_with(f.content, " ") } {
                False -> Error("No")
                True -> Ok(first)
              }
            }
          }
        }
      }
    }
  }
}

fn wrap_math(children: List(VXML)) -> Result(List(VXML), DesugaringError) {
  case children {
    [] -> Ok([])
    [first, ..rest] -> {
      case first {
        T(_, _) -> {
          use rest <- result.try(wrap_math(rest))
          Ok([first, ..rest])
        }
        V(b, t, _, _) -> {
          case t == "Math" {
            False -> {
              use rest <- result.try(wrap_math(rest))
              Ok([first, ..rest])
            }
            True -> {
              use wrapped_rest <- result.try(wrap_math(rest))
              case check_if_next_is_line_that_starts_with_none_space(rest) {
                Error(_) -> Ok([first, ..wrapped_rest])
                Ok(vxml) -> {
                  let assert [_, ..rest] = wrapped_rest
                  Ok([V(b, "NoBreak", [], [first, vxml]), ..rest])
                }
              }
            }
          }
        }
      }
    }
  }
}

pub fn wrap_math_with_no_break_transform(
  node: VXML,
  _: Nil,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(b, t, a, children) -> {
      use new_children <- result.try(wrap_math(children))
      Ok(V(b, t, a, new_children))
    }
  }
}

fn transform_factory() -> NodeToNodeTransform {
  fn(node) { wrap_math_with_no_break_transform(node, Nil) }
}

fn desugarer_factory() -> Desugarer {
  fn(vxml) { depth_first_node_to_node_desugarer(vxml, transform_factory()) }
}

pub fn wrap_math_with_no_break_desugarer() -> Pipe {
  #(
    DesugarerDescription(
      "wrap_math_with_no_break_desugarer",
      option.None,
      "...",
    ),
    desugarer_factory(),
  )
}
