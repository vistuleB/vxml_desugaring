import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn children_before(children: List(VXML), before_tag: String, acc: List(VXML)) -> #(List(VXML), List(VXML)) {
  case children {
    [] -> #([], [])
    [first, ..rest] -> {
      case first {
        V(_, tag, _, _) if tag == before_tag -> #(acc, children)
        _ -> {
          let #(acc, rest) = children_before(rest, before_tag, acc)
          #([first, ..acc], rest)
        }
      }
    }
  }
}

fn transform(
  node: VXML,
  param: InnerParam
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, stop_tag, wrapper_tag) = param
  case node {
    V(b, tag, att, children) if tag == parent_tag -> {
        let #(before, after) = children_before(children, stop_tag, [])
        let children = [
          V(b, wrapper_tag, [], before),
          ..after,
        ]
        Ok(V(b, tag, att, children))
    }
    _ -> Ok(node)
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)

type InnerParam = Param

/// Wraps children of a node that appear before a certain child
/// #Extra
/// - `parent tag` -
/// - `tag to stop at` -
/// - `wrapper tag` -
pub fn wrap_children_before_in(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "wrap_children_before_in",
      Some(ins(param)),
      "Wraps children of a node that appear before a certain child",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
