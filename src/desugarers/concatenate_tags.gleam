import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn concatenate_tags_in_list(vxmls: List(VXML), param: InnerParam) -> List(VXML) {
  case vxmls {
    [] -> []
    [V(_, tag1, _, _) as v1, V(_, tag2, _, _) as v2, ..rest] -> {
      case tag1 == tag2 && list.contains(param, tag1) {
        True -> [v1, ..concatenate_tags_in_list(rest, param)]
        False -> [v1, ..concatenate_tags_in_list([v2, ..rest], param)]
      }
    }
    [first, ..rest] -> [first, ..concatenate_tags_in_list(rest, param)]
  }
}

fn transform(node: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs, children |> concatenate_tags_in_list(param)))
    _ -> Ok(node)
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

pub fn concatenate_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "concatenate_tags",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
