import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{ type VXML, BlamedContent, T, V }

fn nodemap(
  vxml: VXML,
  ancestors: List(VXML),
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case infra.use_list_pair_as_dict(inner, tag) {
        Ok(#(ancestor_tag, if_version, else_version)) -> {
          let ancestor_tags = ancestors |> list.map(infra.get_tag)
          let text = case list.contains(ancestor_tags, ancestor_tag) {
            True -> if_version
            False -> else_version
          }
          let contents = string.split(text, "\n")
          let new_text_node =
            T(
              blame,
              list.map(
                contents,
                fn (content) { BlamedContent(blame, content) }
              )
            )
          Ok(
            V(blame, tag, attrs, [new_text_node, ..children])
          )
        }
        Error(Nil) -> Ok(vxml)
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.FancyOneToOneNodeMap {
  fn(vxml, ancestors, _, _, _) {
    nodemap(vxml, ancestors, inner)
  }
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.fancy_one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> infra.quads_to_pairs
  |> Ok
}

type Param =
  List(#(String, String,    String,      String))
//       ↖       ↖          ↖            ↖
//       tag     ancestor   if_version   else_version

type InnerParam =
  List(#(String, #(String, String, String)))

const name = "prepend_text_if_has_ancestor_else"
const constructor = prepend_text_if_has_ancestor_else

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// prepend one of two specified text fragments to
/// nodes of a certain tag depending on wether the 
/// node has an ancestor of specified type or not
pub fn prepend_text_if_has_ancestor_else(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// prepend one of two specified text fragments to
/// nodes of a certain tag depending on wether the 
/// node has an ancestor of specified type or not
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
      param: [#("ze_tag", "ze_ancestor", "_if_text_", "_else_text_")],
      source:   "
                <> root
                  <> ze_tag
                    <>
                      \"some text V1\"
                  <> ze_ancestor
                    <> distraction
                      <> ze_tag
                        <>
                          \"some text V2\"
                  <> ze_tag
                    <> AnotherNode
                      a=b
                ",
      expected: "
                <> root
                  <> ze_tag
                    <>
                      \"_else_text_\"
                    <>
                      \"some text V1\"
                  <> ze_ancestor
                    <> distraction
                      <> ze_tag
                        <>
                          \"_if_text_\"
                        <>
                          \"some text V2\"
                  <> ze_tag
                    <>
                      \"_else_text_\"
                    <> AnotherNode
                      a=b
                ",
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
