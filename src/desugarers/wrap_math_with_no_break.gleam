import gleam/option
import gleam/result
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import vxml_parser.{type VXML, BlamedContent, T, V}

fn split_next_line_nodes_by_space(rest: List(VXML)) -> Result(List(VXML), Nil) {
  case rest {
    [] -> Error(Nil)
    [first, ..] -> {
      case first {
        V(_, _, _, _) -> Error(Nil)
        T(b, a) -> {
          case a {
            [] -> Error(Nil)
            [f, ..rest_lines] -> {
              let splits_res = f.content |> string.split_once(" ")
              case splits_res {
                Ok(#(no_break_str, rest_of_str)) -> {
                  let no_break_text_node =
                    T(b, [BlamedContent(f.blame, no_break_str)])

                  let rest_text_node =
                    T(b, [
                      BlamedContent(f.blame, " " <> rest_of_str),
                      ..rest_lines
                    ])

                  Ok([no_break_text_node, rest_text_node])
                }
                Error(_) -> Ok([first])
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
              case split_next_line_nodes_by_space(rest) {
                Error(_) -> Ok([first, ..wrapped_rest])
                Ok(vxmls) -> {
                  let assert [_, ..rest] = wrapped_rest
                  case vxmls {
                    [one] -> Ok([V(b, "NoBreak", [], [first]), one, ..rest])
                    [no_break_node, rest_nodes] -> {
                      let assert T(_, [no_break_text]) = no_break_node

                      case no_break_text.content {
                        "" ->
                          Ok([V(b, "NoBreak", [], [first]), rest_nodes, ..rest])
                        _ ->
                          Ok([
                            V(b, "NoBreak", [], [first, no_break_node]),
                            rest_nodes,
                            ..rest
                          ])
                      }
                    }
                    _ -> Ok([])
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn wrap_math_with_no_break_transform(
  node: VXML,
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
  wrap_math_with_no_break_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn wrap_math_with_no_break() -> Pipe {
  #(
    DesugarerDescription("wrap_math_with_no_break", option.None, "..."),
    desugarer_factory(),
  )
}
