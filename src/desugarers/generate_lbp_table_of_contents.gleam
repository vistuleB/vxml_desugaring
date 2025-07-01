import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn blame_us(note: String) -> Blame {
  Blame("generate_lbp_toc:" <> note, -1, -1, [])
}

fn chapter_link(
  chapter_link_component_name: String,
  item: VXML,
  count: Int,
) -> Result(VXML, DesugaringError) {
  let assert V(blame, tag, _, _) = item
  let tp = case tag {
    _ if tag == "Chapter" -> "chapter"
    _ if tag == "Bootcamp" -> "bootcamp"
    _ -> panic as "expecting 'Chapter' or 'Bootcamp'"
  }

  use title_element <- infra.on_error_on_ok(
    infra.unique_child_with_tag(item, "ArticleTitle"),
    fn (s) {
      case s {
        infra.MoreThanOne -> Error(DesugaringError(item.blame, "has more than one ArticleTitle child"))
        infra.LessThanOne -> Error(DesugaringError(item.blame, "has no ArticleTitle child"))
      }
    }
  )

  let assert V(_, _, _, _) = title_element

  Ok(
    V(
      blame,
      chapter_link_component_name,
      [
        BlamedAttribute(blame_us("L42"), "article_type", ins(count)),
        BlamedAttribute(blame_us("L43"), "href", tp <> ins(count)),
      ],
      title_element.children,
    ),
  )
}

fn type_of_chapters_title(
  type_of_chapters_title_component_name: String,
  label: String,
) -> VXML {
  V(
    blame_us("L55"),
    type_of_chapters_title_component_name,
    [BlamedAttribute(blame_us("L57"), "label", label)],
    [],
  )
}

fn div_with_id_title_and_menu_items(
  type_of_chapters_title_component_name: String,
  id: String,
  title_label: String,
  menu_items: List(VXML),
) -> VXML {
  V(
    blame_us("L69"),
    "div",
    [BlamedAttribute(blame_us("L71"), "id", id)], 
    [
      type_of_chapters_title(type_of_chapters_title_component_name, title_label),
      V(blame_us("L74"), "ul", [], menu_items),
    ]
  )
}

fn at_root(root: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  let #(
    table_of_contents_tag,
    type_of_chapters_title_component_name,
    chapter_link_component_name,
    maybe_spacer,
  ) = param

  use chapter_menu_items <- result.then(
    infra.children_with_tag(root, "Chapter")
    |> list.index_map(fn(chapter: VXML, index) { chapter_link(chapter_link_component_name, chapter, index + 1) })
    |> result.all
  )

  use bootcamp_menu_items <- result.then(
    infra.children_with_tag(root, "Bootcamp")
    |> list.index_map(fn(bootcamp: VXML, index) { chapter_link(chapter_link_component_name, bootcamp, index + 1) })
    |> result.all
  )

  let chapters_div =
    div_with_id_title_and_menu_items(
      type_of_chapters_title_component_name,
      "chapter",
      "Chapters",
      chapter_menu_items,
    )

  let bootcamps_div =
    div_with_id_title_and_menu_items(
      type_of_chapters_title_component_name,
      "bootcamp",
      "Bootcamps",
      bootcamp_menu_items,
    )

  let exists_bootcamps = !list.is_empty(bootcamp_menu_items)
  let exists_chapters = !list.is_empty(chapter_menu_items)

  let children = list.flatten([
    case exists_chapters {
      True -> [chapters_div]
      False -> []
    },
    case exists_bootcamps, exists_chapters, maybe_spacer {
      True, True, Some(spacer_tag) -> [V(blame_us("L124"), spacer_tag, [], [])]
      _, _, _ -> []
    },
    case exists_bootcamps {
      True -> [bootcamps_div]
      False -> []
    },
  ])

  Ok(infra.prepend_child(
    root,
    V(blame_us("L135"), table_of_contents_tag, [], children),
  ))
}

fn desugarer_factory(param: InnerParam) -> infra.Desugarer {
  at_root(_, param)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String,   String,                String,        Option(String))
//  ↖         ↖                      ↖              ↖
//  tag name  tag name               tag name       optional tag name
//  table of  of 'big title'         individual     for spacer between
//  contents  (Chapters, Bootcamps)  chapter links  two groups of chapter links

type InnerParam = Param

pub fn generate_lbp_table_of_contents(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "generate_lbp_table_of_contents",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
