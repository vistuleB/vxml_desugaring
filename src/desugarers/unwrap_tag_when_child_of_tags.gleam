import gleam/list
import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

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
      let #(to_be_unwrapped, possible_parents) = extra
      case to_be_unwrapped == tag {
        False -> Ok([vxml])
        True -> {
          case list.first(ancestors) {
            Error(Nil) -> Ok([vxml])
            Ok(first) -> {
              let assert V(_, first_tag, _, _) = first
              case list.contains(possible_parents, first_tag) {
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

type Extra =
  #(String, List(String))

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    param_transform(node, ancestors, s1, s2, s3, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

pub fn unwrap_tag_when_child_of_tags(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("split_vertical_chunks_desugarer", None, "..."),
    desugarer_factory(extra),
  )
}
