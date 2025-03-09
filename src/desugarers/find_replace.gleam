import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{
  type Desugarer, type NodeToNodesFancyTransform, type Pipe,
  DesugarerDescription,
} as infra

fn transform_factory(extra: Extra) -> NodeToNodesFancyTransform {
  let #(string_pairs, forbidden_parents) = extra
  infra.find_replace_in_node_transform_version(_, string_pairs)
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

type Extra =
  #(List(#(String, String)), List(String))
//         from    to        keep_out_of

pub fn find_replace(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("find_replace", Some(ins(extra)), "..."),
    desugarer_factory(extra),
  )
}
