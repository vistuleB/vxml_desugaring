import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case list.contains(inner, tag) {
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)

type InnerParam = Param

/// encodes spaces in first and last child of specified tags
pub fn encode_spaces_in_first_and_last_child(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "encode_spaces_in_first_and_last_child",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// encodes spaces in first and last child of specified tags
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}