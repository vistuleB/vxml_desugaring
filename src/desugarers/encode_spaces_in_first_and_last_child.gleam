import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn param_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case list.contains(extra, tag) {
        True -> {
          Ok(V(
            blame,
            tag,
            attrs,
            children
              |> infra.encode_starting_spaces_in_first_node
              |> infra.encode_ending_spaces_in_last_node,
          ))
        }
        False -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(String)

pub fn encode_spaces_in_first_and_last_child(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "encode_spaces_in_first_and_last_child",
      option.Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
