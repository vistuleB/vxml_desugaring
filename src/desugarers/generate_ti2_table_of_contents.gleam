import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn blame_us(note: String) -> Blame {
  Blame("generate_ti2_toc:" <> note, -1, -1, [])
}

fn prepand_0(number: String) {
  case string.length(number) {
    1 -> "0" <> number
    _ -> number
  }
}

fn chapter_link(
  chapter_link_component_name: String,
  item: VXML,
  _: Int,
) -> Result(VXML, DesugaringError) {
  let tp = "Chapter"

  let item_blame = infra.get_blame(item)

  use label_attr <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "title_gr"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents)" <> tp <> " missing title_gr attribute",
    )),
  )

  use href_attr <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "title_en"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents)" <> tp <> " missing title_en attribute",
    )),
  )

  use number_attribute <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "number"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents)" <> tp <> " missing number attribute",
    )),
  )

  let on_mobile_attr = case infra.get_attribute_by_name(item, "on_mobile") {
    Some(attr) -> attr
    None -> label_attr
  }

  let link =
    number_attribute.value
    |> string.split(".")
    |> list.map(prepand_0)
    |> string.join("-")
    <> "-"
    <> href_attr.value |> string.replace(" ", "-")

  Ok(
    V(
      item_blame,
      chapter_link_component_name,
      [
        BlamedAttribute(label_attr.blame, "label", label_attr.value),
        BlamedAttribute(on_mobile_attr.blame, "on_mobile", on_mobile_attr.value),
        BlamedAttribute(
          number_attribute.blame,
          "number",
          number_attribute.value,
        ),
        BlamedAttribute(blame_us("L45"), "href", link),
      ],
      [],
    ),
  )
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

fn transform(root: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  let #(table_of_contents_tag, chapter_link_component_name) = param
  let sections = infra.descendants_with_tag(root, "Section")
  use chapter_menu_items <- infra.on_error_on_ok(
    over: {
      sections
      |> list.index_map(fn(chapter: VXML, index) {
        chapter_link(chapter_link_component_name, chapter, index + 1)
      })
      |> result.all
    },
    with_on_error: Error,
  )

  let chapters_div =
    div_with_id_title_and_menu_items("Chapters", chapter_menu_items)

  Ok(infra.prepend_child(
    root,
    V(blame_us("L104"), table_of_contents_tag, [], [chapters_div]),
  ))
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> infra.Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String)

// - first string: tag name for table of contents
// - second string: tag name for individual chapter links
// - third string: optional tag name for spacer between two groups of chapter links

type InnerParam = Param

pub fn generate_ti2_table_of_contents(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "generate_ti2_table_of_contents",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
