import blamedlines.{type Blame}
import gleam/list
import gleam/option.{None}
import gleam/result
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V}

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
  parent_tag: String,
  tag_wrapper_pairs: List(#(String, String)),
) -> VXML {
  let #(blame, children) = blame_and_children

  let #(_, wrapper) =
    tag_wrapper_pairs
    |> list.find(fn(pair) {
      let #(tag_, _) = pair
      tag_ == parent_tag
    })
    |> result.unwrap(#("", "VerticalChunk"))

  V(blame, wrapper, [], children)
}

fn split_vertical_chunks_transform(
  vxml: VXML,
  tag_wrapper_pairs: List(#(String, String)),
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let new_children =
        lists_of_non_blank_line_chunks(children)
        |> list.map(chunk_constructor(_, tag, tag_wrapper_pairs))
      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

type Extras =
  #(
    List(
      String,
      // List to exclude from vertical chunking
    ),
    List(#(String, String)),
    // List of tag and wrapper pairs
  )

fn transform_factory(extras: Extras) -> infra.NodeToNodeFancyTransform {
  let #(excluded_tags, wrappers) = extras
  infra.prevent_node_to_node_transform_inside(
    split_vertical_chunks_transform(_, wrappers),
    excluded_tags,
  )
}

fn desugarer_factory(extras: Extras) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(extras))
}

pub fn split_vertical_chunks(extras: Extras) -> Pipe {
  #(
    DesugarerDescription("split_vertical_chunks_desugarer", None, "..."),
    desugarer_factory(extras),
  )
}
