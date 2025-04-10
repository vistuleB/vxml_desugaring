import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V}

const ins = string.inspect

fn param_transform(
  node: VXML,
  tags: List(String),
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case list.contains(tags, tag) && list.length(children) <= 1 {
        False -> Ok([node])
        True -> Ok(children)
      }
    _ -> Ok([node])
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(String)
//      ↖
//       tag to be
//       unwrapped

pub fn unwrap_when_single_child(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap_when_single_child", Some(ins(extra)), "unwraps based on tag name if node
has no siblings"),
    desugarer: desugarer_factory(extra),
  )
}
