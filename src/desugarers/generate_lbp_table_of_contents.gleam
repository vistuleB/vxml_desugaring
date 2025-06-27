import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/option.{type Option, None, Some}
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

  // use label_attr <- infra.on_none_on_some(
  //   infra.v_attribute_with_key(item, "title"),
  //   with_on_none: Error(DesugaringError(
  //     blame,
  //     tp <> " missing title attribute",
  //   )),
  // )

  // let on_mobile_attr = case infra.v_attribute_with_key(item, "on_mobile") {
  //   Some(attr) -> attr
  //   None -> label_attr
  // }

  use title_element <- infra.on_error_on_ok(
    infra.unique_child_with_tag(item, "ArticleTitleNewStyle"),
    fn (s) {
      case s {
        infra.MoreThanOne -> Error(DesugaringError(item.blame, "has more than one ArticleTitleNewStyle child"))
        infra.LessThanOne -> Error(DesugaringError(item.blame, "has no ArticleTitleNewStyle child"))
      }
    }
  )

  let assert V(_, _, _, _) = title_element

  Ok(
    V(
      blame,
      chapter_link_component_name,
      [
        BlamedAttribute(blame_us("L41"), "article_type", ins(count)),
        // BlamedAttribute(label_attr.blame, "label", label_attr.value),
        // BlamedAttribute(on_mobile_attr.blame, "on_mobile", on_mobile_attr.value),
        BlamedAttribute(blame_us("L44"), "href", tp <> ins(count)),
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

fn at_root(root: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  let #(
    table_of_contents_tag,
    type_of_chapters_title_component_name,
    chapter_link_component_name,
    maybe_spacer,
  ) = param
  let chapters = infra.children_with_tag(root, "Chapter")
  let bootcamps = infra.children_with_tag(root, "Bootcamp")

  use chapter_menu_items <- infra.on_error_on_ok(
    over: {
      chapters
      |> list.index_map(fn(chapter: VXML, index) { chapter_link(chapter_link_component_name, chapter, index + 1) })
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
