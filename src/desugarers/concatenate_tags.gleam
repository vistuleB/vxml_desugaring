import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, V}

fn concatenate_tags_in_list(vxmls: List(VXML), extra: Extra) -> List(VXML) {
  case vxmls {
    [] -> []
    [V(_, tag1, _, _) as v1, V(_, tag2, _, _) as v2, ..rest] -> {
      case tag1 == tag2 && list.contains(extra, tag1) {
        True -> [v1, ..concatenate_tags_in_list(rest, extra)]
        False -> [v1, ..concatenate_tags_in_list([v2, ..rest], extra)]
      }
    }
    [first, ..rest] -> [first, ..concatenate_tags_in_list(rest, extra)]
  }
}

fn param_transform(node: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attrs, children) ->
      Ok(V(blame, tag, attrs, children |> concatenate_tags_in_list(extra)))
    _ -> Ok(node)
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

pub fn concatenate_tags(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "concatenate_tags",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
