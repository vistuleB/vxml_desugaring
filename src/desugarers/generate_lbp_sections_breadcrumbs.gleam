import gleam/string
import gleam/result
import gleam/list
import infrastructure.{type Pipe, Pipe, DesugarerDescription, type DesugaringError, DesugaringError} as infra
import gleam/option
import vxml.{type VXML, V, T, BlamedContent, BlamedAttribute}

const ins = string.inspect

fn remove_period(nodes: List(VXML)) -> List(VXML) {
  use last <- infra.on_error_on_ok(
    list.last(nodes),
    fn(_) { nodes }
  )

  use <- infra.on_lazy_false_on_true(
    infra.is_text_node(last),
    fn(){
      // in case last node is a V node . call remove period recursvaly on it's children
      let assert V(b, t, a, children) = last
      list.flatten([
        list.take(nodes, list.length(nodes) - 1),
        [V(b, t, a, remove_period(children))]
      ])
    }
  )

  let assert T(b, lines) = last
  use last_line <- infra.on_error_on_ok(
    list.last(lines),
    fn(_) { nodes }
  )
  // some Text nodes ends with "" . so it should be ignored and remove_period on nodes without last one
  use <- infra.on_false_on_true(
    last_line.content != "",
    list.take(nodes, list.length(nodes) - 1)
    |> remove_period()
  )

  let new_last_line = case string.ends_with(last_line.content, ".") {
    True -> {
      BlamedContent(last_line.blame, string.drop_end(last_line.content, 1))
    }
    False -> last_line
  }
  // replace last BlamedContent
  let new_t = T(b, list.flatten([
    list.take(lines, list.length(lines) - 1),
    [new_last_line]
  ]))
  // replace last node
  list.flatten([
    list.take(nodes, list.length(nodes) - 1),
    [new_t]
  ])
}

fn small_caps_t(t: VXML) -> VXML{
  let assert T(b, contents) = t
  contents
  |> list.map(fn(line){
    BlamedContent(line.blame, string.lowercase(line.content))
  })
  |> T(b, _)
}

fn small_caps_nodes(nodes: List(VXML), result: List(VXML)) -> List(VXML) {
  case nodes {
    [] -> result |> list.reverse
    [first, ..rest] -> {
      case first {
        T(_, _) -> small_caps_nodes(rest, [small_caps_t(first), ..result])  
        V(b, t, a, children) -> small_caps_nodes(rest, [
          V(b, t, a, small_caps_nodes(children, [])),
          ..result
        ])
      }
    }
  }
}

fn transform_children(children: List(VXML)) -> List(VXML){
  children
  |> small_caps_nodes([])
  |> remove_period()
}

fn construct_breadcrumb(children: List(VXML), target_id: String, index: Int) -> VXML {
  let blame = infra.blame_us("generate_lbp_sections_breadcrumbs")

   let link = V(blame, "InChapterLink", [
        BlamedAttribute(blame, "href", "?id=" <> target_id),
      ], children)

  V(blame, "BreadcrumbItem", [
    BlamedAttribute(blame, "class", "breadcrumb"),
    BlamedAttribute(blame, "id", "breadcrumb-" <> ins(index)),
  ], [link])
}

fn map_section(section: VXML, index: Int) -> Result(VXML, DesugaringError) {
  case infra.get_children(section) {
    [V(_, "BreadcrumbTitle", _, children), ..] -> {
      children
      |> transform_children
      |> construct_breadcrumb("section-" <> ins(index + 1), index)
      |> Ok
    }
    _ -> Error(DesugaringError(section.blame, "Section must have a BreadcrumbTitle as first child"))
  }
}

fn generate_sections_list(sections: List(VXML), exercises: List(VXML)) -> Result(VXML, DesugaringError) {
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
    _ -> panic as "We don't have more than one exercises section"
  }

  Ok(V(infra.blame_us("generate_lbp_sections_breadcrumbs"), "SectionsBreadcrumbs", [], list.flatten([sections_nodes, exercises_node])))
}

fn map_chapter(child: VXML) -> Result(VXML, DesugaringError) {
  case child {
    V(b, "Chapter", a, children) -> {
      let sections = infra.children_with_tag(child, "Section")
      let exercises = infra.children_with_tag(child, "Exercises")
      use sections_ul <- result.try(generate_sections_list(sections, exercises)) 
      Ok(V(b, "Chapter", a, [sections_ul, ..children]))
    }
    V(b, "Bootcamp", a, children) -> {
      let sections = infra.children_with_tag(child, "Section")
      let exercises = infra.children_with_tag(child, "Exercises")
      use sections_ul <- result.try(generate_sections_list(sections, exercises)) 
      Ok(V(b, "Bootcamp", a, [sections_ul, ..children]))
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

pub fn generate_lbp_sections_breadcrumbs() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "generate_lbp_sections_breadcrumbs",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(_) -> desugarer_factory()
    },
  )
}
