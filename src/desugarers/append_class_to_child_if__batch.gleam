import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn update_child(
  node: VXML,
  classes_and_conditions: List(#(String, fn(VXML) -> Bool)),
) -> VXML {
  list.fold(
    classes_and_conditions,
    node,
    fn(acc, classes_and_condition) {
      infra.v_append_classes_if(
        acc,
        classes_and_condition.0,
        classes_and_condition.1,
      )
    }
  )
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    T(_, _) -> vxml
    V(_, tag, _, children) -> case dict.get(inner, tag) {
      Error(_) -> vxml
      Ok(classes_and_conditions) -> {
        V(
          ..vxml,
          children: infra.map_v_nodes(children, update_child(_, classes_and_conditions))
        )
      }
    }
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
  param
  |> list.map(infra.quad_drop_4th)
  |> infra.triples_to_aggregated_dict
  |> Ok
}

type Param = List(#(String,  String,     fn(VXML) -> Bool, String))
//                  ↖        ↖           ↖                 ↖
//                  parent   class       condition         string description
//                  tag      to append   function          of condition func.
//                                                         (e.g. 'infra.has_class(_, "my-foot")')
type InnerParam = Dict(String, List(#(String, fn(VXML) -> Bool)))

const name = "append_class_to_child_if__batch"
const constructor = append_class_to_child_if__batch

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// appends a class to children if they meet a
/// condition when they are children of a specified
/// parent tag. takes tuples of
/// (parent_tag, class_to_append, condition_function).
pub fn append_class_to_child_if__batch(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(param |> list.map(infra.quad_drop_3rd) |> infra.list_param_stringifier),
    option.None,
    "
/// appends a class to children if they meet a
/// condition when they are children of a specified
/// parent tag. takes tuples of
/// (parent_tag, class_to_append, condition_function).
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
      param: [#("Chapter", "main-column", infra.tag_equals(_, "p"), "infra.tag_equals(_, \"p\")")],
      source:   "
                <> root
                  <> Chapter
                    <> p
                      class=existing
                    <> div
                      class=other
                    <> p
                      class=another
                  <> Section
                    <> p
                      class=should-not-change
                ",
      expected: "
                <> root
                  <> Chapter
                    <> p
                      class=existing main-column
                    <> div
                      class=other
                    <> p
                      class=another main-column
                  <> Section
                    <> p
                      class=should-not-change
                "
    ),
    infra.AssertiveTestData(
      param: [#("container", "active", infra.has_class(_, "highlight"), "infra.has_class(_, \"highlight\")")],
      source:   "
                <> root
                  <> container
                    <> span
                      class=highlight
                    <> span
                      class=normal
                    <> div
                      class=highlight bold
                ",
      expected: "
                <> root
                  <> container
                    <> span
                      class=highlight active
                    <> span
                      class=normal
                    <> div
                      class=highlight bold active
                "
    ),
    infra.AssertiveTestData(
      param: [
        #("parent", "new", infra.tag_equals(_, "child"), "infra.tag_equals(_, \"child\")"),
        #("other", "different", infra.has_class(_, "special"), "infra.has_class(_, \"special\")")
      ],
      source:   "
                <> root
                  <> parent
                    <> child
                      class=original
                    <> other
                      class=base
                  <> other
                    <> child
                      class=special
                ",
      expected: "
                <> root
                  <> parent
                    <> child
                      class=original new
                    <> other
                      class=base
                  <> other
                    <> child
                      class=special different
                "
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
