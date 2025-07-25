import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, V}

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
      [
        first,
        inner.2,
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
    V(_, _, _, children) ->
      V(..node, children: add_in_list(children, inner))
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
  #(
    param.0,
    param.1,
    infra.blame_tag_attrs_2_v(
      "add_between",
      param.2,
      param.3,
    ),
  )
  |> Ok
}

type Param = #(String,          String, String,         List(#(String, String)))
//             ↖                ↗       ↖               ↖
//             insert divs              tag name for    attributes for
//             between adjacent         new element     new element
//             siblings of these
//             two names
type InnerParam = #(String, String, VXML)

const name = "add_between"
const constructor = add_between

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds new elements between adjacent tags of
/// specified types
pub fn add_between(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
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