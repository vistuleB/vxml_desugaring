import gleam/list
import gleam/option
import gleam/regexp
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedContent, T, V}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, t, atts, children) -> {
      // remove carousel buttons
      use <- infra.on_false_on_true(
        over: infra.v_has_key_value(vxml, "class", "chapterTitle")
          || infra.v_has_key_value(vxml, "class", "subChapterTitle"),
        with_on_false: Ok(vxml),
      )

      let assert [
        T(
          t_blame,
          [BlamedContent(l_blame, first_text_node_line), ..rest_contents],
        ),
        ..rest_children
      ] = children
      let assert Ok(re) = regexp.from_string("^(\\d+)(\\.(\\d+)?)?\\s")
      regexp.check(re, first_text_node_line)

      use <- infra.on_false_on_true(
        over: regexp.check(re, first_text_node_line),
        with_on_false: Ok(vxml),
      )

      let new_line = regexp.replace(re, first_text_node_line, "")
      let contents =
        T(t_blame, [
          BlamedContent(l_blame, new_line),
          ..list.drop(rest_contents, 1)
        ])
      let children = [contents, ..list.drop(rest_children, 1)]

      Ok(V(blame, t, atts, children))
    }
    _ -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub const desugarer_name = "remove_chapter_number_from_title"
pub const desugarer_pipe = remove_chapter_number_from_title

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// removes chapter numbers from titles in chapter and subchapter title elements
pub fn remove_chapter_number_from_title() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.None,
      general_description: "
/// removes chapter numbers from titles in chapter and subchapter title elements
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(desugarer_name, assertive_tests_data(), desugarer_pipe)
}
