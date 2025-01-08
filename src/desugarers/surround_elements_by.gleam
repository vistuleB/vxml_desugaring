import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodesTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML, T, V}

fn surround_elements_by_transform(
  node: VXML,
  params: Param,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> Ok([node])
    V(blame, tag, _, _) -> {
      case dict.get(params, tag) {
        Error(Nil) -> Ok([node])
        Ok(#(above_tag, below_tag)) -> {
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

type Param =
  Dict(String, #(String, String))

//*******************************
// the three tuple elements:
//    - list of tag names to surround
//    - name of tag to place above, or "" if none (for each tag of first list, all treated same)
//    - name of tag to place below, or "" if none (for each tag of first list, all treated same)
//*******************************
type Extra =
  #(List(String), String, String)

fn extra_to_param(extra: Extra) -> Param {
  let #(els, above, below) = extra
  els
  |> list.map(fn(el) { #(el, #(above, below)) })
  |> dict.from_list
}

fn transform_factory(params: Param) -> NodeToNodesTransform {
  // wrap_elements_by_blankline_transform(_, extra)
  surround_elements_by_transform(_, params)
}

fn desugarer_factory(params: Param) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(params))
}

pub fn surround_elements_by(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "surround_elements_by",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra_to_param(extra)),
  )
}
