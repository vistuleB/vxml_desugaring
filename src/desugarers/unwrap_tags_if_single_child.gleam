import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, V}

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

type Extra =
  List(String)

fn transform_factory(extra: Extra) -> infra.NodeToNodesTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

pub fn unwrap_tags_if_single_child(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap_tags_if_single_child", Some(ins(extra)), "..."),
    desugarer: desugarer_factory(extra),
  )
}
