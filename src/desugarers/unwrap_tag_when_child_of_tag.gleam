import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
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
      let #(to_be_unwrapped, parent) = extra
      case to_be_unwrapped == tag {
        False -> Ok([vxml])
        True -> {
          case list.first(ancestors) {
            Error(Nil) -> Ok([vxml])
            Ok(first) -> {
              let assert V(_, first_tag, _, _) = first
              case first_tag == parent {
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
  #(String, String)

pub fn unwrap_tag_when_child_of_tag(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("unwrap_tag_when_child_of_tag", option.Some(extra |> ins), "..."),
    desugarer_factory(extra),
  )
}
