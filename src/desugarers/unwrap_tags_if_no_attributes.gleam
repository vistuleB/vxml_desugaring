import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V}

fn param_transform(
  node: VXML,
  tags: List(String),
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, [], children) ->
      case list.contains(tags, tag) {
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

pub fn unwrap_tags_if_no_attributes(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "unwrap_tags_if_no_attributes",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
