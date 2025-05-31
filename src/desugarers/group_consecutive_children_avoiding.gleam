import gleam/list
import gleam/option.{Some}
import gleam/string
import infrastructure.{type Desugarer,type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

const ins = string.inspect

fn is_forbidden(elem: VXML, forbidden: List(String)) {
  case elem {
    T(_, _) -> False
    V(_, tag, _, _) -> list.contains(forbidden, tag)
  }
}

fn transform(
  vxml: VXML,
  _: List(VXML),
  param: InnerParam,
) -> infra.EarlyReturn(VXML) {
  let #(wrapper_tag, forbidden_to_include, forbidden_to_enter) = param
  case vxml {
    T(_, _) -> infra.GoBack(vxml)
    V(blame, tag, attrs, children) -> {
      use <- infra.on_true_on_false(
        list.contains(forbidden_to_enter, tag),
        infra.GoBack(vxml),
      )

      use <- infra.on_true_on_false(tag == wrapper_tag, infra.Continue(vxml))

      let children =
        children
        |> infra.either_or_misceginator(is_forbidden(_, forbidden_to_include))
        |> infra.regroup_ors_no_empty_lists
        |> infra.map_either_ors(fn(elem) { elem }, fn(consecutive_siblings) {
          V(
            consecutive_siblings |> infra.assert_get_first_blame,
            wrapper_tag,
            [],
            consecutive_siblings,
          )
        })

      infra.Continue(V(blame, tag, attrs, children))
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.EarlyReturnNodeToNodeTransform {
  fn(vxml, ancestors) { transform(vxml, ancestors, param) }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.early_return_node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, List(String), List(String))

//********************************
// - String: name of wrapper tag
// - List(String): do not wrap these
// - List(String): do not even enter these
//********************************

type InnerParam = Param

pub fn group_consecutive_children_avoiding(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "group_consecutive_children_avoiding",
      Some(ins(param)),
      "wrap consecutive children whose tags
are not in the excluded list inside
of a designated parent tag; stay
out of subtrees rooted at tags
in the second argument",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
