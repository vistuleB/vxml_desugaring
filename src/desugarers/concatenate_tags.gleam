import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn concatenate_tags_in_list(vxmls: List(VXML), inner: InnerParam) -> List(VXML) {
  case vxmls {
    [] -> []
    [V(_, tag1, _, _) as v1, V(_, tag2, _, _) as v2, ..rest] -> {
      case tag1 == tag2 && list.contains(inner, tag1) {
        True -> [v1, ..concatenate_tags_in_list(rest, inner)]
        False -> [v1, ..concatenate_tags_in_list([v2, ..rest], inner)]
      }
    }
    [first, ..rest] -> [first, ..concatenate_tags_in_list(rest, inner)]
  }
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs, children |> concatenate_tags_in_list(inner)))
    _ -> Ok(node)
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

/// concatenates adjacent tags with the same name
pub fn concatenate_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "concatenate_tags",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// concatenates adjacent tags with the same name
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}