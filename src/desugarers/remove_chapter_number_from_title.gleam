import gleam/list
import gleam/option.{None}
import gleam/regexp
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedContent, T, V}

fn transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, t, atts, children) -> {
      // remove carousel buttons
      use <- infra.on_false_on_true(
        over: infra.has_attribute(vxml, "class", "chapterTitle")
          || infra.has_attribute(vxml, "class", "subChapterTitle"),
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

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

pub fn remove_chapter_number_from_title() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "remove_chapter_number_from_title",
      None,
      "...",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
