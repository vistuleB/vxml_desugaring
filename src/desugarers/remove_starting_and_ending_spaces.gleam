import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML, T, V}

const ins = string.inspect

fn param_transform(vxml: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, tag, _, _) -> {
      case list.contains(extra, tag) {
        True -> {
          let #(_, vxml) = vxml |> infra.v_extract_starting_spaces
          let #(_, vxml) = vxml |> infra.v_extract_ending_spaces
          Ok(vxml)
        }
        False -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(extra: Extra) -> NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra = List(String)

pub fn remove_starting_and_ending_spaces(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "remove_starting_and_ending_spaces",
      option.Some(ins(extra)),
      "..."
    ),
    desugarer_factory(extra),
  )
}
