import blamedlines.{type Blame}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

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

fn transform(vxml: VXML, wrapper: String) -> Result(VXML, DesugaringError) {
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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeFancyTransform {
  infra.prevent_node_to_node_transform_inside(
    transform(_, inner.0),
    inner.1,
  )
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String,      List(String))
//  ↖            ↖
//  name of      keep out
//  wrapper      of these
//  tag

type InnerParam = Param

/// wrap siblings that are not separated by
/// WriterlyBlankLine inside a designated tag
/// and remove WriterlyBlankLine elements;
/// stays out of subtrees designated by
/// tags in the second 'List(String)' argument
pub fn group_siblings_not_separated_by_blank_lines(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "group_siblings_not_separated_by_blank_lines",
      stringified_param: option.Some(ins(param)),
      general_description:
      "
/// wrap siblings that are not separated by
/// WriterlyBlankLine inside a designated tag
/// and remove WriterlyBlankLine elements;
/// stays out of subtrees designated by
/// tags in the second 'List(String)' argument
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}