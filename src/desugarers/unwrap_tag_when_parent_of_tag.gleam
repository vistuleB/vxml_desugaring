import gleam/list
import gleam/option
import gleam/pair
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

fn param_transform(
  vxml: VXML,
  extra: Extra,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      case list.any(
        extra,
        fn(pair) { tag == pair |> pair.first }
      ) {
        False -> Ok([vxml])
        True -> {
          case list.any(
            children,
            fn (child) {
              case child {
                T(_, _) -> False
                V(_, child_tag, _, _) -> list.contains(extra, #(tag, child_tag))
              }
            }
          ) {
            False -> Ok([vxml])
            True -> Ok(children)
          }
        }
      }
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(#(String, String))

pub fn unwrap_tag_when_parent_of_tag(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("unwrap_tag_when_parent_of_tag", option.Some(extra |> ins), "..."),
    desugarer_factory(extra),
  )
}
