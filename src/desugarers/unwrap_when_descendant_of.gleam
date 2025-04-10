import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V}

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
      case infra.use_list_pair_as_dict(extra, tag) {
        Error(Nil) -> Ok([node])
        Ok(forbidden) -> {
          let ancestor_names = list.map(ancestors, infra.get_tag)
          case list.any(ancestor_names, list.contains(forbidden, _)) {
            True -> Ok(children)
            False -> Ok([node])
          }
        }
      }
    _ -> Ok([node])
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
  fn(vxml: VXML, s1: List(VXML), s2: List(VXML), s3: List(VXML), s4: List(VXML)) {
    param_transform(vxml, s1, s2, s3, s4, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(#(String,    List(String)))
//        ↖            ↖
//         tag to be    list of ancestor names
//         unwrapped    that will cause tag to unwrap

pub fn unwrap_when_descendant_of(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap_when_descendant_of", Some(ins(extra)), "unwraps tags that are the descendant of
one of a stipulated list of tag names"),
    desugarer: desugarer_factory(extra),
  )
}
