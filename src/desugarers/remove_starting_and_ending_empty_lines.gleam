import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, T, V}

const ins = string.inspect

fn param_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, tag, _, _) -> {
      case list.contains(extra, tag) {
        True -> {
          vxml
          |> infra.v_remove_starting_and_ending_empty_lines
          |> Ok
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

pub fn remove_starting_and_ending_empty_lines(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_starting_and_ending_empty_lines",
      option.Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
