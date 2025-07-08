
import gleam/string.{inspect as ins}
import gleam/result
import gleam/list
import infrastructure.{type Pipe, Pipe, type DesugaringError, DesugaringError} as infra
import gleam/option
import vxml.{type VXML, V, T, BlamedContent, BlamedAttribute}

fn remove_period(nodes: List(VXML)) -> List(VXML) {
  use #(head, last) <- infra.on_error_on_ok(
    infra.head_last(nodes),
    fn(_){nodes}
  )

  use <- infra.on_lazy_false_on_true(
    infra.is_text_node(last),
    fn() {
      let assert V(_, _, _, children) = last
      list.append(head, [infra.replace_children_with(last, remove_period(children))])
    }
  )

  use last <- infra.on_none_on_some(
    infra.t_super_trim_end_and_remove_ending_period(last),
    head,
  )

  list.append(head, [last])
}

fn lowercase_t(t: VXML) -> VXML{
  let assert T(b, contents) = t
  contents
  |> list.map(fn(bc) { BlamedContent(..bc, content: string.lowercase(bc.content)) })
  |> T(b, _)
}

fn lowercase_vxml(
  node: VXML,
) -> VXML {
  case node {
    T(_, _) -> lowercase_t(node)
    V(_, _, _, children) -> V(
      ..node,
      children: list.map(children, lowercase_vxml)
    )
  }
}

fn cleanup_children(children: List(VXML)) -> List(VXML){
  children
  |> list.map(lowercase_vxml)
  |> remove_period
}

fn construct_breadcrumb(children: List(VXML), target_id: String, index: Int) -> VXML {
  let blame = infra.blame_us("generate_lbp_section_breadcrumbs")
  V(
    blame,
    "BreadcrumbItem",
    [BlamedAttribute(blame, "id", "breadcrumb-" <> ins(index))],
    [
      V(
        blame,
        "InChapterLink",
        [BlamedAttribute(blame, "href", "?id=" <> target_id)],
        children |> cleanup_children,
      ),
    ]
  )
}

fn map_section(section: VXML, index: Int) -> Result(VXML, DesugaringError) {
  case infra.get_children(section) {
    [V(_, "BreadcrumbTitle", _, children), ..] -> Ok(construct_breadcrumb(children, "section-" <> ins(index + 1), index))
    _ -> Error(DesugaringError(section.blame, "Section must have a BreadcrumbTitle as first child"))
  }
}

fn generate_sections_list(
  sections: List(VXML),
  exercises: List(VXML),
) -> Result(VXML, DesugaringError) {
  use sections_nodes <- result.try(
    list.index_map(sections, map_section)
    |> result.all
  )

  let exercises_node = case exercises {
    [] -> []
    [one] -> {
      [
        construct_breadcrumb(
          [T(one.blame, [BlamedContent(one.blame, "exercises")])],
          "exercises",
          list.length(sections_nodes)
        )
      ]
    }
    _ -> panic as "there should not be more than one exercises section"
  }

  Ok(V(
    infra.blame_us("generate_lbp_section_breadcrumbs"),
    "SectionsBreadcrumbs",
    [],
    list.flatten([sections_nodes, exercises_node])
  ))
}

fn remove_breadcrumb_title(
  vxml: VXML,
) -> VXML {
  case vxml {
    V(_, "Section", _, children) -> {
      let assert [V(_, "BreadcrumbTitle", _, _), ..] = children
      V(..vxml, children: list.drop(children, 1))
    }
    _ -> vxml
  }
}

fn map_chapter(child: VXML) -> Result(VXML, DesugaringError) {
  case child {
    V(b, tag, a, children) if tag == "Chapter" || tag == "Bootcamp" -> {
      let sections = infra.children_with_tag(child, "Section")
      let exercises = infra.children_with_tag(child, "Exercises")
      use sections_ul <- result.try(generate_sections_list(sections, exercises)) 
      Ok(V(b, tag, a, [sections_ul, ..children |> list.map(remove_breadcrumb_title)]))
    }
    _ -> Ok(child)
  }
}

fn at_root(root: VXML) -> Result(VXML, DesugaringError) {
  let children = infra.get_children(root)

  use updated_children <- result.try(
    children
    |> list.map(map_chapter)
    |> result.all
  )

  Ok(infra.replace_children_with(root, updated_children))
}

fn desugarer_factory() -> infra.Desugarer {
  at_root
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

pub const desugarer_name = "generate_lbp_breadcrumbs"
pub const desugarer_pipe = generate_lbp_breadcrumbs

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
pub fn generate_lbp_breadcrumbs() -> Pipe {
  Pipe(
    desugarer_name,
    option.None,
    "...",
    case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(_) -> desugarer_factory()
    },
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