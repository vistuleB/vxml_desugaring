import gleam/dict.{type Dict}
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn update_children_with_tag(
  children: List(VXML),
  tag_class_mappings: List(#(String, String)),
) -> List(VXML) {
  infra.map_children_with_conditional_class_append(
    children,
    tag_class_mappings,
    fn(child, target_tag) {
      case child {
        T(_, _) -> False
        V(_, tag, _, _) -> tag == target_tag
      }
    }
  )
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
        Ok(tag_class_mappings) -> {
          let updated_children = update_children_with_tag(
            children,
            tag_class_mappings,
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
//       parent  list of (child_tag, class_to_append) pairs
//       tag

type InnerParam = Dict(String, List(#(String, String)))

const name = "append_class_to_children_with_tag"
const constructor = append_class_to_children_with_tag

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// appends a class to children with a specific tag
/// when they are children of a specified parent tag.
/// takes tuples of (parent_tag, list_of_tag_class_mappings).
pub fn append_class_to_children_with_tag(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// appends a class to children with a specific tag
/// when they are children of a specified parent tag.
/// takes tuples of (parent_tag, list_of_tag_class_mappings).
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
      param: [#("Chapter", [#("p", "main-column")])],
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
      param: [#("container", [#("span", "highlight"), #("div", "block")])],
      source:   "
                <> root
                  <> container
                    <> span
                      class=text
                    <> div
                      class=content
                    <> p
                      class=unchanged
                ",
      expected: "
                <> root
                  <> container
                    <> span
                      class=text highlight
                    <> div
                      class=content block
                    <> p
                      class=unchanged
                "
    ),
    infra.AssertiveTestData(
      param: [#("parent", [#("child", "new")]), #("other", [#("child", "different")])],
      source:   "
                <> root
                  <> parent
                    <> child
                      class=original
                  <> other
                    <> child
                      class=base
                  <> parent
                    <> child
                ",
      expected: "
                <> root
                  <> parent
                    <> child
                      class=original new
                  <> other
                    <> child
                      class=base different
                  <> parent
                    <> child
                      class=new
                "
    )
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
