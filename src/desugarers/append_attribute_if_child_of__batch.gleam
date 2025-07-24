import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, V}

fn nodemap(
  vxml: VXML,
  ancestors: List(VXML),
  inner: InnerParam,
) -> VXML {
  use blame, tag, attributes, children <- infra.on_t_on_v(
    vxml,
    fn(_, _) {vxml}
  )

  use parent, _ <- infra.on_lazy_empty_on_nonempty(ancestors, fn() { vxml })

  let assert V(_, parent_tag, _, _) = parent

  use attributes_to_add <- infra.on_error_on_ok(
    dict.get(inner, #(tag, parent_tag)),
    fn(_) { vxml }
  )

  let old_attribute_keys = infra.get_attribute_keys(attributes)

  let attributes_to_add =
    list.fold(
      over: attributes_to_add,
      from: [],
      with: fn(so_far, pair) {
        let #(key, value) = pair
        case list.contains(old_attribute_keys, key) {
          True -> so_far
          False -> [BlamedAttribute(blame, key, value), ..so_far]
        }
      }
    )
    |> list.reverse

  V(blame, tag, list.append(attributes, attributes_to_add), children)
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToOneNoErrorNodeMap {
  fn(vxml, ancestors, _, _, _) { nodemap(vxml, ancestors, inner) }
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.fancy_one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param
  |> infra.quadruples_to_pairs_pairs
  |> infra.aggregate_on_first)
}

type Param = List(#(String, String, String, String))
//                  ↖       ↖       ↖       ↖
//                  tag     parent  attr    value
type InnerParam = Dict(#(String, String), List(#(String, String)))

const name = "append_attribute_if_child_of_depr"
const constructor = append_attribute_if_child_of_depr

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// adds an attribute-pair to a tag when it is the 
/// child of another specified tag; will not 
/// overwrite if attribute with that key already
/// exists
pub fn append_attribute_if_child_of_depr(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// adds an attribute-pair to a tag when it is the
/// child of another specified tag; will not 
/// overwrite if attribute with that key already
/// exists
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
  [
    infra.AssertiveTestData(
      param: [#("B", "parent", "key1", "val1")],
      source:   "
                <> root
                  <> B
                    <> parent
                  <> parent
                    <> B
                  <> parent
                    <> B
                      key1=val2
                ",
      expected: "
                <> root
                  <> B
                    <> parent
                  <> parent
                    <> B
                      key1=val1
                  <> parent
                    <> B
                      key1=val2
                "
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}