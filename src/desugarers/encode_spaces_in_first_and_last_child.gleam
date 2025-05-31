import gleam/list
import gleam/option
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,Pipe} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn transform(vxml: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case list.contains(param, tag) {
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(String)

type InnerParam = Param

pub fn encode_spaces_in_first_and_last_child(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "encode_spaces_in_first_and_last_child",
      option.Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
