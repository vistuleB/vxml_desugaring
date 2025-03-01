import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import blamedlines.{type Blame, Blame}
import vxml_parser.{type VXML, V, T, BlamedAttribute, BlamedContent}

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


  let link = 
    "lecture-notes/"
    <> number_attribute.value |> string.split(".") |> list.map(prepand_0) |> string.join("-") 
    <> "-" 
    <> href_attr.value |> string.replace(" ", "-")
    <> ".html"

  let number_span = V(item_blame, "span", [], [
    T(blame_us("L53"), [BlamedContent(blame_us("L53"), number_attribute.value <> " - ")])
  ])
  let a = V(item_blame, "a", [
    BlamedAttribute(blame_us("L57"), "href", link)
  ], [
    T(item_blame, [BlamedContent(item_blame, label_attr.value)])
  ])

  let sub_chapter_number = number_attribute.value |> string.split(".") |> list.last() |> result.unwrap("0")
  let margin_left = infra.on_true_on_false(
    sub_chapter_number == "0",
    "0",
    fn() { "40px" }
  )

  let style_attr = BlamedAttribute(blame_us("L68"), "style", "margin-left: " <> margin_left)

  Ok(V(
    item_blame,
    chapter_link_component_name,
    [
      style_attr
    ],
    [
      number_span,
      a
    ]
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
  let sections = infra.descendants_with_tag(root, "section")

  use chapter_menu_items <- infra.on_error_on_ok(
    over: {
        sections
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
