import gleam/list
import gleam/option
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, type DesugaringWarning, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, V}
import blamedlines as bl

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
    infra.v_attribute_with_key(item, "title_gr"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents)" <> tp <> " missing title_gr attribute",
    )),
  )

  use href_attr <- infra.on_none_on_some(
    infra.v_attribute_with_key(item, "title_en"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents)" <> tp <> " missing title_en attribute",
    )),
  )

  use number_attribute <- infra.on_none_on_some(
    infra.v_attribute_with_key(item, "number"),
    with_on_none: Error(DesugaringError(
      item_blame,
      "(generate_ti2_table_of_contents)" <> tp <> " missing number attribute",
    )),
  )

  let on_mobile_attr = case infra.v_attribute_with_key(item, "on_mobile") {
    option.Some(attr) -> attr
    option.None -> label_attr
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
        BlamedAttribute(desugarer_blame(75), "href", link),
      ],
      [],
    ),
  )
}

fn div_with_id_title_and_menu_items(id: String, menu_items: List(VXML)) -> VXML {
  V(desugarer_blame(83), "div", [BlamedAttribute(desugarer_blame(83), "id", id)], [
    V(
      desugarer_blame(85),
      "ul",
      [BlamedAttribute(desugarer_blame(87), "style", "list-style: none")],
      menu_items,
    ),
  ])
}

fn at_root(
  root: VXML,
  inner: InnerParam,
) -> Result(#(VXML, List(DesugaringWarning)), DesugaringError) {
  let #(table_of_contents_tag, chapter_link_component_name) = inner
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

  infra.prepend_child(
    root,
    V(desugarer_blame(116), table_of_contents_tag, [], [chapters_div]),
  )
  |> n2t.add_warnings
  |> Ok
}

fn transform_factory(inner: InnerParam) -> infra.DesugarerTransform {
  at_root(_, inner)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String,         String)
//             ↖               ↖
//             table of        chapter
//             contents tag    component name
type InnerParam = Param

pub const name = "generate_ti2_table_of_contents"
const constructor = generate_ti2_table_of_contents
fn desugarer_blame(line_no: Int) {bl.Des([], name, line_no)}

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// generates table of contents for TI2 content with
/// sections
pub fn generate_ti2_table_of_contents(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// generates table of contents for TI2 content with
/// sections
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
