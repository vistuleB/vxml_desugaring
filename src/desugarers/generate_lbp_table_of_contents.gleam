import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe,
} as infra
import vxml_parser.{type VXML, BlamedAttribute, V}

const ins = string.inspect

fn blame_us(note: String) -> Blame {
  Blame("generate_lbp_toc:" <> note, -1, [])
}

fn chapter_link(
  chapter_link_component_name: String,
  item: VXML,
  count: Int,
) -> Result(VXML, DesugaringError) {
  let tp = case infra.tag_equals(item, "Chapter") {
    True -> "chapter"
    False -> {
      let assert True = infra.tag_equals(item, "Bootcamp")
      "bootcamp"
    }
  }

  let item_blame = infra.get_blame(item)

  use label_attr <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "title"),
    with_on_none: Error(DesugaringError(
      item_blame,
      tp <> " missing title attribute",
    )),
  )

  let on_mobile_attr = case infra.get_attribute_by_name(item, "on_mobile") {
    Some(attr) -> attr
    None -> label_attr
  }

  Ok(
    V(
      item_blame,
      chapter_link_component_name,
      [
        BlamedAttribute(blame_us("L41"), "article_type", ins(count)),
        BlamedAttribute(label_attr.blame, "label", label_attr.value),
        BlamedAttribute(on_mobile_attr.blame, "on_mobile", on_mobile_attr.value),
        BlamedAttribute(blame_us("L44"), "href", tp <> ins(count)),
      ],
      [],
    ),
  )
}

fn type_of_chapters_title(
  type_of_chapters_title_component_name: String,
  label: String,
) -> VXML {
  V(
    blame_us("L52"),
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
  V(blame_us("87"), "div", [BlamedAttribute(blame_us("L72"), "id", id)], [
    type_of_chapters_title(type_of_chapters_title_component_name, title_label),
    V(blame_us("L95"), "ul", [], menu_items),
  ])
}

fn the_desugarer(root: VXML, extra: Extra) -> Result(VXML, DesugaringError) {
  let #(
    table_of_contents_tag,
    type_of_chapters_title_component_name,
    chapter_link_component_name,
    maybe_spacer,
  ) = extra
  let chapters = infra.children_with_tag(root, "Chapter")
  let bootcamps = infra.children_with_tag(root, "Bootcamp")

  use chapter_menu_items <- infra.on_error_on_ok(
    over: {
      chapters
      |> list.index_map(fn(chapter: VXML, index) {
        chapter_link(chapter_link_component_name, chapter, index + 1)
      })
      |> result.all
    },
    with_on_error: Error,
  )

  use bootcamp_menu_items <- infra.on_error_on_ok(
    over: {
      bootcamps
      |> list.index_map(fn(bootcamp: VXML, index) {
        chapter_link(chapter_link_component_name, bootcamp, index + 1)
      })
      |> result.all
    },
    with_on_error: Error,
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

  let children = case
    list.is_empty(chapter_menu_items),
    list.is_empty(bootcamp_menu_items),
    maybe_spacer
  {
    True, True, _ -> []
    False, True, _ -> [chapters_div]
    True, False, _ -> [bootcamps_div]
    False, False, None -> [chapters_div, bootcamps_div]
    False, False, Some(spacer_tag) -> [
      chapters_div,
      V(blame_us("L145"), spacer_tag, [], []),
      bootcamps_div,
    ]
  }

  Ok(infra.prepend_child(
    root,
    V(blame_us("L142"), table_of_contents_tag, [], children),
  ))
}

type Extra =
  #(String, String, String, Option(String))

// - first string: tag name for table of contents
// - second string: tag name of "big title" (Chapters, Bootcamps)
// - third string: tag name for individual chapter links
// - third string: optional tag name for spacer between two groups of chapter links

pub fn generate_lbp_table_of_contents(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "generate_lbp_table_of_contents",
      option.None,
      "...",
    ),
    desugarer: the_desugarer(_, extra),
  )
}
