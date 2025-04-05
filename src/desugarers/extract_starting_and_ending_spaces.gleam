import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn param_transform(
  vxml: VXML,
  extra: Extra,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, _) -> {
      case list.contains(extra, tag) {
        True -> {
          let #(before, vxml) = vxml |> infra.v_extract_starting_spaces
          let #(after, vxml) = vxml |> infra.v_extract_ending_spaces
          Ok(option.values([before, Some(vxml), after]))
        }
        False -> Ok([vxml])
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
  List(String)

pub fn extract_starting_and_ending_spaces(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "extract_starting_and_ending_spaces",
      option.Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
