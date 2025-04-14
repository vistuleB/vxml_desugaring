import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
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

fn param_transform(
  node: VXML,
  extra: Extra
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, stop_tag, wrapper_tag) = extra
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

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra = #(String, String, String)

/// Wraps children of a node that appear before a certain child
/// #Extra
/// - `parent tag` - 
/// - `tag to stop at` - 
/// - `wrapper tag` - 
pub fn wrap_children_before_in(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "wrap_children_before_in",
      Some(ins(extra)),
      "Wraps children of a node that appear before a certain child",
    ),
    desugarer: desugarer_factory(extra),
  )
}
