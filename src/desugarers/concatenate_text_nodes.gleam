import gleam/list
import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn concatenate_lines_in(nodes: List(VXML)) -> VXML {
  let assert [first, ..] = nodes
  let assert T(blame, _) = first
  let all_lines = {
    nodes
    |> list.map(fn(node) {
      let assert T(_, blamed_lines) = node
      blamed_lines
    })
    |> list.flatten
  }
  T(blame, all_lines)
}

fn param_transform(node: VXML) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, children) -> {
      let new_children =
        children
        |> infra.either_or_misceginator(infra.is_text_node)
        |> infra.regroup_eithers_no_empty_lists
        |> infra.map_either_ors(
          fn(either: List(VXML)) -> VXML { concatenate_lines_in(either) },
          fn(or: VXML) -> VXML { or },
        )
      Ok(V(blame, tag, attributes, new_children))
    }
    _ -> Ok(node)
  }
}

fn transform_factory() -> infra.NodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn concatenate_text_nodes() -> Pipe {
  Pipe(
    description: DesugarerDescription("concatenate_text_nodes", None, "..."),
    desugarer: desugarer_factory(),
  )
}
