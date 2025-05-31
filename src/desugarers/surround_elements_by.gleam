import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  node: VXML,
  ancestors: List(VXML),
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(blame, tag, _, _) -> {
      case dict.get(param, tag), list.length(ancestors) > 0 {
        Error(Nil), _ -> Ok([node])
        _, False -> Ok([node])
        Ok(#(above_tag, below_tag)), True -> {
          let some_none_above = case above_tag == "" {
            True -> None
            False ->
              Some(
                V(blame: blame, tag: above_tag, attributes: [], children: []),
              )
          }
          let some_none_below = case below_tag == "" {
            True -> None
            False ->
              Some(
                V(blame: blame, tag: below_tag, attributes: [], children: []),
              )
          }
          case some_none_above, some_none_below {
            None, None -> Ok([node])
            None, Some(below) -> Ok([node, below])
            Some(above), None -> Ok([above, node])
            Some(above), Some(below) -> Ok([above, node, below])
          }
        }
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, _, _, _) {
    transform(node, ancestors, param)
  }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let #(els, above, below) = param
  let inner_param = els
    |> list.map(fn(el) { #(el, #(above, below)) })
    |> dict.from_list
  Ok(inner_param)
}

type Param =
  #(List(String), String, String)

type InnerParam =
  Dict(String, #(String, String))

//*******************************
// the three tuple elements:
//    - list of tag names to surround
//    - name of tag to place above, or "" if none (for each tag of first list, all treated same)
//    - name of tag to place below, or "" if none (for each tag of first list, all treated same)
//*******************************

pub fn surround_elements_by(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "surround_elements_by",
      option.Some(string.inspect(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
