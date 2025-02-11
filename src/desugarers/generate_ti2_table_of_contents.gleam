import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import blamedlines.{type Blame, Blame}
import vxml_parser.{type VXML, V, BlamedAttribute}

const ins = string.inspect

fn blame_us(note: String) -> Blame {
  Blame("generate_ti2_toc:" <> note, -1, [])
}

fn prepand_0(number: String) {
  case string.length(number) {
    1 -> "0" <> number
    _ -> number
  }
}

fn chapter_link(chapter_link_component_name : String, item: VXML, count: Int) -> Result(VXML, DesugaringError) {
  let tp = "Chapter"

  let item_blame = infra.get_blame(item)

  use label_attr <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "title_gr"),
    with_on_none: Error(DesugaringError(item_blame, tp <> " missing title_gr attribute"))
  )

  use href_attr <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "title_en"),
    with_on_none: Error(DesugaringError(item_blame, tp <> " missing title_en attribute"))
  )

  use number_attribute <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "number"),
    with_on_none: Error(DesugaringError(item_blame, tp <> " missing number attribute"))
  )

  let on_mobile_attr = case infra.get_attribute_by_name(item, "on_mobile") {
    Some(attr) -> attr
    None -> label_attr
  }

  let link = 
    number_attribute.value |> string.split(".") |> list.map(prepand_0) |> string.join("-") 
    <> "-" 
    <> href_attr.value |> string.replace(" ", "-")

  Ok(V(
    item_blame,
    chapter_link_component_name,
    [
      BlamedAttribute(label_attr.blame, "label", label_attr.value),
      BlamedAttribute(on_mobile_attr.blame, "on_mobile", on_mobile_attr.value),
      BlamedAttribute(number_attribute.blame, "number", number_attribute.value),
      BlamedAttribute(blame_us("L45"), "href", link),
    ],
    []
  ))
}


fn div_with_id_title_and_menu_items(
  id: String,
  menu_items: List(VXML)
) -> VXML {
  V(
    blame_us("57"),
    "div",
    [
      BlamedAttribute(blame_us("L60"), "id", id)
    ],
    [
      V(
        blame_us("L64"),
        "ul",
        [
          BlamedAttribute(blame_us("68"), "style", "list-style: none")
        ],
        menu_items
      )
    ]
  )
}

fn the_desugarer(
  root: VXML,
  table_of_contents_tag: String,
  chapter_link_component_name : String,
  _: Option(String),
) -> Result(VXML, DesugaringError) {
  let chapters = infra.children_with_tag(root, "Chapter")

  use chapter_menu_items <- infra.on_error_on_ok(
    over: {
        chapters
        |> list.index_map(
          fn(chapter : VXML, index) { chapter_link(chapter_link_component_name, chapter, index + 1) }
        )
        |> result.all
    },
    with_on_error: Error
  )


  let chapters_div = div_with_id_title_and_menu_items(
    "Chapters",
    chapter_menu_items
  )

  Ok(
    infra.prepend_child(
      root,
      V(
        blame_us("L104"),
        table_of_contents_tag,
        [],
        [chapters_div]
      )
    )
  )
}

// - first string: tag name for table of contents
// - second string: tag name for individual chapter links
// - third string: optional tag name for spacer between two groups of chapter links
type Extra = #(String, String, Option(String))

pub fn generate_ti2_table_of_contents(extra: Extra) -> Pipe {
  let #(tag, chapter_link_component_name, maybe_spacer) = extra
  #(
    DesugarerDescription("generate_ti2_table_of_contents", option.None, "..."),
    fn (vxml) {
      the_desugarer(
        vxml,
        tag,
        chapter_link_component_name,
        maybe_spacer
      )
    },
  )
}
