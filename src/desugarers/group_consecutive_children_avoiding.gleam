import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer,type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}


fn is_forbidden(elem: VXML, forbidden: List(String)) {
  case elem {
    T(_, _) -> False
    V(_, tag, _, _) -> list.contains(forbidden, tag)
  }
}

fn transform(
  vxml: VXML,
  _: List(VXML),
  inner: InnerParam,
) -> infra.EarlyReturn(VXML) {
  let #(wrapper_tag, forbidden_to_include, forbidden_to_enter) = inner
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

fn transform_factory(inner: InnerParam) -> infra.EarlyReturnNodeToNodeTransform {
  fn(vxml, ancestors) { transform(vxml, ancestors, inner) }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.early_return_node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, List(String), List(String))
//  ↖       ↖            ↖
//  name    do not       do not
//  of      wrap         even
//  wrapper these        enter
//  tag                  these

type InnerParam = Param

pub const desugarer_name = "group_consecutive_children_avoiding"
pub const desugarer_pipe = group_consecutive_children_avoiding

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// wrap consecutive children whose tags
/// are not in the excluded list inside
/// of a designated parent tag; stay
/// out of subtrees rooted at tags
/// in the second argument
pub fn group_consecutive_children_avoiding(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// wrap consecutive children whose tags
/// are not in the excluded list inside
/// of a designated parent tag; stay
/// out of subtrees rooted at tags
/// in the second argument
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}