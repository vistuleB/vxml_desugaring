import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn update_children_with_multiple_classes(
  children: List(VXML),
  class_mappings: List(#(String, String)),
) -> List(VXML) {
  list.map(children, fn(child) {
    case child {
      T(_, _) -> child
      V(blame, tag, attributes, grandchildren) -> {
        let updated_attributes = list.fold(
          class_mappings,
          attributes,
          fn(current_attributes, mapping) {
            let #(target_class, class_to_append) = mapping
            case infra.has_class(V(blame, tag, current_attributes, grandchildren), target_class) {
              True -> infra.add_to_class_attribute(current_attributes, blame, class_to_append)
              False -> current_attributes
            }
          }
        )
        V(blame, tag, updated_attributes, grandchildren)
      }
    }
  })
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attributes, children) -> {
      case dict.get(inner, tag) {
        Error(Nil) -> Ok(vxml)
        Ok(class_mappings) -> {
          let updated_children = update_children_with_multiple_classes(
            children,
            class_mappings,
          )
          Ok(V(blame, tag, attributes, updated_children))
        }
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(dict.from_list(param))
}

type Param =
  List(#(String, List(#(String, String))))
//       ↖       ↖
//       parent  list of (target_class, class_to_append) pairs
//       tag

type InnerParam = Dict(String, List(#(String, String)))

const name = "append_class_to_children_with_class"
const constructor = append_class_to_children_with_class

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// checks all children of a given parent tag for
/// existence of a specific class value and if found,
/// appends a new class value to the class attribute.
/// takes tuples of (parent_tag, list_of_class_mappings).
pub fn append_class_to_children_with_class(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// checks all children of a given parent tag for
/// existence of a specific class value and if found,
/// appends a new class value to the class attribute.
/// takes tuples of (parent_tag, list_of_class_mappings).
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
      param: [#("Chapter", [#("well", "out")])],
      source:   "
                <> root
                  <> Chapter
                    <> div
                      class=well
                    <> div
                      class=other
                    <> p
                      class=well
                  <> Section
                    <> div
                      class=well
                ",
      expected: "
                <> root
                  <> Chapter
                    <> div
                      class=well out
                    <> div
                      class=other
                    <> p
                      class=well out
                  <> Section
                    <> div
                      class=well
                "
    ),
    infra.AssertiveTestData(
      param: [#("container", [#("highlight", "active")])],
      source:   "
                <> root
                  <> container
                    <> span
                      class=highlight
                    <> span
                      class=highlight bold
                    <> div
                      class=normal
                ",
      expected: "
                <> root
                  <> container
                    <> span
                      class=highlight active
                    <> span
                      class=highlight bold active
                    <> div
                      class=normal
                "
    ),
    infra.AssertiveTestData(
      param: [#("parent", [#("target", "new")]), #("other", [#("different", "added")])],
      source:   "
                <> root
                  <> parent
                    <> child
                      class=target
                  <> other
                    <> child
                      class=different
                ",
      expected: "
                <> root
                  <> parent
                    <> child
                      class=target new
                  <> other
                    <> child
                      class=different added
                "
    ),
    infra.AssertiveTestData(
      param: [#("Chapter", [#("well", "out"), #("highlight", "active")])],
      source:   "
                <> root
                  <> Chapter
                    <> div
                      class=well highlight
                    <> div
                      class=important
                    <> div
                      class=other
                ",
      expected: "
                <> root
                  <> Chapter
                    <> div
                      class=well highlight out active
                    <> div
                      class=important
                    <> div
                      class=other
                "
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
