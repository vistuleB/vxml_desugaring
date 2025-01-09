import blamedlines.{type Blame}
import gleam/list
import gleam/string
import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

const ins = string.inspect

fn lists_of_non_blank_line_chunks(
  vxmls: List(VXML),
) -> List(#(Blame, List(VXML))) {
  infra.either_or_misceginator(vxmls, infra.is_tag(_, "WriterlyBlankLine"))
  |> infra.regroup_ors_no_empty_lists
  |> infra.remove_eithers_unwrap_ors
  |> list.map(fn(vxmls: List(VXML)) {
    #(infra.assert_get_first_blame(vxmls), vxmls)
  })
}

pub fn chunk_constructor(
  blame_and_children: #(Blame, List(VXML)),
  wrapper: String,
) -> VXML {
  let #(blame, children) = blame_and_children
  V(blame, wrapper, [], children)
}

fn param_transform(
  vxml: VXML,
  wrapper: String,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let new_children =
        lists_of_non_blank_line_chunks(children)
        |> list.map(chunk_constructor(_, wrapper))
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

//********************************
// - String: name of wrapper tag
// - List(String): keep out of these
//********************************
type Extra =
  #(String, List(String))

fn transform_factory(extra: Extra) -> infra.NodeToNodeFancyTransform {
  let #(wrapper, excluded_tags) = extra
  infra.prevent_node_to_node_transform_inside(
    param_transform(_, wrapper),
    excluded_tags,
  )
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(extra))
}

pub fn group_siblings_not_separated_by_blank_lines(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "group_siblings_not_separated_by_blank_lines " <> ins(extra),
      None,
      "wrap siblings that are not separated by
WriterlyBlankLine inside a designated tag
and remove WriterlyBlankLine elements;
stays out of subtrees designated by
tags in the second 'List(String)' argument"
    ),
    desugarer_factory(extra),
  )
}
