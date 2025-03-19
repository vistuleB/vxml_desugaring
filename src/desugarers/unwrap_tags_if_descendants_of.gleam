import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, V}

fn param_transform(
  node: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  extra: Extra,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case list.find(extra, fn(pair) { pair |> pair.first == tag }) {
        Ok(pair) -> {
          let forbidden = pair |> pair.second
          let ancestor_names = list.map(ancestors, infra.get_tag)
          case list.any(ancestor_names, list.contains(forbidden, _)) {
            True -> Ok(children)
            False -> Ok([node])
          }
        }
        Error(Nil) -> Ok([node])
      }
    _ -> Ok([node])
  }
}

type Extra =
  List(#(String, List(String)))

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
  fn(vxml: VXML, s1: List(VXML), s2: List(VXML), s3: List(VXML), s4: List(VXML)) {
    param_transform(vxml, s1, s2, s3, s4, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

pub fn unwrap_tags_if_descendants_of(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "unwrap_tags_if_descendants_of",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
