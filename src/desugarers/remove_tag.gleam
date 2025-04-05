import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V}

fn remove_tag_transform(
  vxml: VXML,
  extra: List(String),
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    V(_, tag, _, _) ->
      case list.contains(extra, tag) {
        True -> Ok([])
        False -> Ok([vxml])
      }
    _ -> Ok([vxml])
  }
}

fn transform_factory(extra: List(String)) -> infra.NodeToNodesTransform {
  remove_tag_transform(_, extra)
}

fn desugarer_factory(extra: List(String)) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

pub fn remove_tag_desugarer(extra: List(String)) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_tag_desugarer",
      option.None,
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
