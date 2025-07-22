import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, type BlamedAttribute, BlamedAttribute, V}

fn add_in_list(
  children: List(VXML),
  inner: InnerParam,
) -> List(VXML) {
  case children {
    [
      V(_, first_tag, _, _) as first,
      V(_, second_tag, _, _) as second,
      ..rest
    ] if first_tag == inner.0 && second_tag == inner.1 -> {
      let blame = infra.blame_us("add_between_tags_no_list")
      [
        first,
        V(
          blame,
          inner.2,
          inner.3,
          [],
        ),
        ..add_in_list([second, ..rest], inner),
      ]
    }
    [first, ..rest] -> [first, ..add_in_list(rest, inner)]
    _ -> children
  }
}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> VXML {
  case node {
    V(_, _, _, children) -> V(..node, children: add_in_list(children, inner))
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
  let blame = infra.blame_us("add_between_tags_no_list")
  #(
    param.0,
    param.1,
    param.2,
    list.map(
      param.3,
      fn(pair) { BlamedAttribute(blame, pair.0, pair.1) }
    )
  )
  |> Ok
}

type Param = #(String,          String, String,         List(#(String, String)))
//             ↖                ↗       ↖               ↖
//             insert divs              tag name for    attributes for
//             between adjacent         new element     new element
//             siblings of these
//             two names
type InnerParam = #(String, String, String, List(BlamedAttribute))

const name = "add_between_tags_no_list"
const constructor = add_between_tags_no_list

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds new elements between adjacent tags of
/// specified types
pub fn add_between_tags_no_list(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// adds new elements between adjacent tags of
/// specified types
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