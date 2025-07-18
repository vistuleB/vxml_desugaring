import blamedlines.{type Blame}
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, BlamedContent, T, V}

fn blame_us(note: String) -> Blame {
  infra.blame_us("(generate_ti2_table_of_contents_html.gleam:" <> note <> ")")
}

fn prepend_0(number: String) {
  case string.length(number) {
    1 -> "0" <> number
    _ -> number
  }
}

fn chapter_link(
  chapter_link_component_name: String,
  item: VXML,
  section_index: Int,
) -> Result(VXML, DesugaringError) {
  let tp = "Chapter"

  let item_blame = infra.get_blame(item)

  use label_attr <- infra.on_none_on_some(
    infra.v_attribute_with_key(item, "title_gr"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents_html) "
        <> tp
        <> " missing title_gr attribute",
    )),
  )

  use href_attr <- infra.on_none_on_some(
    infra.v_attribute_with_key(item, "title_en"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents_html) "
        <> tp
        <> " missing title_en attribute",
    )),
  )

  use number_attribute <- infra.on_none_on_some(
    infra.v_attribute_with_key(item, "number"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents_html) "
        <> tp
        <> " missing number attribute",
    )),
  )

  let link =
    "lecture-notes/"
    <> number_attribute.value
    |> string.split(".")
    |> list.map(prepend_0)
    |> string.join("-")
    <> "-"
    <> href_attr.value |> string.replace(" ", "-")
    <> ".html"

  // number span should always increament . for example we have sub-chapters 05-05-a and 05-05-b . so number span should be 5.5 and 5.6 for each
  let assert [chapter_number, ..] = number_attribute.value |> string.split(".")

  let number_span =
    V(item_blame, "span", [], [
      T(blame_us("L53"), [
        BlamedContent(
          blame_us("L53"),
          chapter_number <> "." <> ins(section_index) <> " - ",
        ),
      ]),
    ])

  let a =
    V(item_blame, "a", [BlamedAttribute(blame_us("L57"), "href", link)], [
      T(item_blame, [BlamedContent(item_blame, label_attr.value)]),
    ])

  let sub_chapter_number = ins(section_index)
  let margin_left =
    infra.on_true_on_false(sub_chapter_number == "0", "0", fn() { "40px" })

  let style_attr =
    BlamedAttribute(blame_us("L68"), "style", "margin-left: " <> margin_left)

  Ok(V(item_blame, chapter_link_component_name, [style_attr], [number_span, a]))
}

fn get_section_index(item: VXML, count: Int) -> Result(Int, DesugaringError) {
  let tp = "Chapter"
  let item_blame = infra.get_blame(item)

  use number_attribute <- infra.on_none_on_some(
    infra.v_attribute_with_key(item, "number"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents_html) "
        <> tp
        <> " missing number attribute (b)",
    )),
  )

  let assert [section_number, ..] =
    number_attribute.value |> string.split(".") |> list.reverse()
  let assert Ok(section_number) = int.parse(section_number)

  case section_number == 0 {
    True -> Ok(0)
    False -> Ok(count + 1)
  }
}

fn div_with_id_title_and_menu_items(id: String, menu_items: List(VXML)) -> VXML {
  V(blame_us("57"), "div", [BlamedAttribute(blame_us("L60"), "id", id)], [
    V(
      blame_us("L64"),
      "ul",
      [BlamedAttribute(blame_us("68"), "style", "list-style: none")],
      menu_items,
    ),
  ])
}

fn nodemap(
  root: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(table_of_contents_tag, chapter_link_component_name) = inner
  let sections = infra.descendants_with_tag(root, "section")
  use chapter_menu_items <- infra.on_error_on_ok(
    over: {
      sections
      |> list.map_fold(0, fn(acc, chapter: VXML) {
        case get_section_index(chapter, acc) {
          Ok(section_index) -> #(
            section_index,
            chapter_link(chapter_link_component_name, chapter, section_index),
          )
          Error(error) -> #(acc, Error(error))
        }
      })
      |> pair.second
      |> result.all
    },
    with_on_error: Error,
  )

  let chapters_div =
    div_with_id_title_and_menu_items("Chapters", chapter_menu_items)

  Ok(infra.prepend_child(
    root,
    V(blame_us("L164"), table_of_contents_tag, [], [chapters_div]),
  ))
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> infra.DesugarerTransform {
  nodemap_factory(inner)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String)
//  ↖       ↖
//  tag     tag name
//  name    for
//  for     individual
//  table   chapter
//  of      links
//  contents

type InnerParam = Param

const name = "generate_ti2_table_of_contents_html"
const constructor = generate_ti2_table_of_contents_html

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// generates HTML table of contents for TI2 content
/// with sections
pub fn generate_ti2_table_of_contents_html(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// generates HTML table of contents for TI2 content
/// with sections
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}