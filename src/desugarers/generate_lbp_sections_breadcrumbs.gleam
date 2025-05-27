import gleam/result
import gleam/list
import infrastructure.{type Pipe, Pipe, DesugarerDescription, type DesugaringError, DesugaringError} as infra
import gleam/option
import vxml.{type VXML, V, T, BlamedContent}


fn first_child_must_be(node: VXML, tag: String, callback: fn(VXML) -> VXML) -> Result(VXML, DesugaringError) {
case infra.get_children(node) |> list.first {
    Ok(V(_, t, _, _) as node) if t == tag -> Ok(callback(node))
    Ok(node) -> {
      [T(node.blame, [BlamedContent(node.blame, "Section x")])]
      |> V(node.blame, "", [], _)
      |> callback
      |> Ok
    }
    _ -> panic as "section cannot be empty"
  }
}

fn map_section(section: VXML) -> Result(VXML, DesugaringError) {
  use vertical_chunk <- result.then(first_child_must_be(section, "VerticalChunk", fn(child){
      child
  }))

  first_child_must_be(vertical_chunk, "b", fn(child){
      let assert V(_, _, _, children) = child
      V(infra.blame_us("generate_lbp_sections_breadcrumbs"), "li", [], children)
  })
}

fn generate_sections_list(sections: List(VXML)) -> Result(VXML, DesugaringError) {
  use sections_nodes <- result.try(
    list.map(sections, map_section)
    |> result.all
  )
  Ok(V(infra.blame_us("generate_lbp_sections_breadcrumbs"), "SectionsBreadcrumbs", [], sections_nodes))
}

fn map_chapter(child: VXML) -> Result(VXML, DesugaringError) {
  case child {
    V(b, "Chapter", a, children) -> {
      let sections = infra.children_with_tag(child, "Section")
      use sections_ul <- result.try(generate_sections_list(sections)) 
      Ok(V(b, "Chapter", a, [sections_ul, ..children]))
    }
    _ -> Ok(child)
  }
}

fn the_desugarer(root: VXML) -> Result(VXML, DesugaringError) {
  let children = infra.get_children(root)

  use updated_children <- result.try(
    list.map(children, map_chapter)
    |> result.all
  )

  Ok(infra.replace_children_with(root, updated_children))
}

pub fn generate_lbp_sections_breadcrumbs() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "generate_lbp_sections_breadcrumbs",
      option.None,
      "...",
    ),
    desugarer: the_desugarer(_),
  )
}
