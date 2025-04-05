import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn param_transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  extra: Extra,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) ->
      case list.any(ancestors, extra) {
        True -> Ok([vxml])
        False -> Ok([])
      }
    V(_, _, _, children) -> {
      case
        !list.is_empty(children) || list.any(ancestors, extra) || extra(vxml)
      {
        True -> Ok([vxml])
        False -> Ok([])
      }
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
  fn(vxml, a, s1, s2, s3) { param_transform(vxml, a, s1, s2, s3, extra) }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

type Extra =
  fn(VXML) -> Bool

pub fn remove_outside_subtrees(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_outside_subtrees",
      option.Some(extra |> ins),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
