import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError } as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, type BlamedAttribute, BlamedAttribute, V}
import blamedlines.{type Blame}

fn add_in_list(
  seen_da_tag_yet: Bool,
  upcoming: List(VXML), 
  inner: InnerParam,
) -> List(VXML) {
  case upcoming {
    [V(_, tag, _, _) as first, ..rest] if tag == inner.0 -> {
      case seen_da_tag_yet {
        False -> [
          first,
          ..add_in_list(True, rest, inner)
        ]
        True -> [
          V(
            inner.3,
            inner.1,
            inner.2,
            [],
          ),
          first,
          ..add_in_list(True, rest, inner),
        ]
      }
    }
    [] -> []
    [first, ..rest] -> [first, ..add_in_list(seen_da_tag_yet, rest, inner)]
  }
}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> VXML {
  case node {
    V(_, _, _, children) ->
      V(..node, children: add_in_list(False, children, inner))
    _ -> node
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let blame = infra.blame_us("add_before...first_of_kind_no_list")
  #(
    param.0,
    param.1,
    list.map(
      param.2,
      fn(pair) { BlamedAttribute(blame, pair.0, pair.1) }
    ),
    blame,
  )
  |> Ok
}

type Param = #(String,        String,          List(#(String, String)))
//             ↖              ↖                ↖
//             insert divs    tag name         attributes
//             before tags    of new element
//             of this name
//             (except if it's the first occurrence of the same kind)
type InnerParam = #(String, String, List(BlamedAttribute), Blame)

const name = "add_before_tags_but_not_before_first_of_kind_no_list"
const constructor = add_before_tags_but_not_before_first_of_kind_no_list

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53

/// adds new elements before specified tags but
/// not before the first occurrence of the same kind
pub fn add_before_tags_but_not_before_first_of_kind_no_list(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// adds new elements before specified tags but
/// not before the first occurrence of the same kind
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
