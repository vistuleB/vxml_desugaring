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
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      case infra.use_list_pair_as_dict(extra, tag) {
        Error(Nil) -> Ok([vxml])
        Ok(parent_tags) -> {
          case list.first(ancestors) {
            Error(Nil) -> Ok([vxml])
            Ok(parent) -> {
              let assert V(_, actual_parent_tag, _, _) = parent
              case list.contains(parent_tags, actual_parent_tag) {
                False -> Ok([vxml])
                True -> Ok(children)
              }
            }
          }
        }
      }
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    param_transform(node, ancestors, s1, s2, s3, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(#(String,     List(String)))
//        ↖            ↖
//         tag to be    list of parent tag names
//         unwrapped    that will cause child to unwrap

/// unwrap nodes based on parent-child
/// relationships
pub fn unwrap_when_child_of(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap_when_child_of", option.Some(ins(extra)), "unwrap nodes based on parent-child
relationships"),
    desugarer: desugarer_factory(extra),
  )
}
