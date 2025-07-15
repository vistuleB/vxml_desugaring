import blamedlines.{type Blame}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugaringError} as infra
import vxml.{type VXML, BlamedAttribute, BlamedContent, V, T}

type PageInfo = #(Int, Int)  // (chapter_no, sub_no)

fn get_course_homepage(document: VXML) -> String {
  case infra.v_attribute_with_key(document, "course_homepage") {
    None -> ""
    Some(x) -> x.value
  }
}

fn format_chapter_link(chapter_no: Int, sub_no: Int) -> String {
  "./" <> ins(chapter_no) <> "-" <> ins(sub_no) <> ".html"
}

fn get_prev_next_info(
  current_chapter: Int,
  current_sub: Int,
  all_pages: List(PageInfo),
) -> #(Option(PageInfo), Option(PageInfo)) {
  let idx = infra.index_of(
    all_pages,
    #(current_chapter, current_sub),
  )
  use <- infra.on_lazy_true_on_false(
    idx < 0,
    fn(){ panic as "#(current_chapter, current_sub) not found in all_pages" }
  )
  #(
    infra.get_at(all_pages, idx - 1) |> option.from_result,
    infra.get_at(all_pages, idx + 1) |> option.from_result,
  )
}

fn a_tag_with_href_and_content(
  blame: Blame,
  href: String,
  content: String,
) -> VXML {
  V(blame, "a", [BlamedAttribute(blame, "href", href)], [T(blame, [BlamedContent(blame, content)])])
}

fn info_2_link(
  blame: Blame,
  info: PageInfo,
  direction: String
) -> VXML {
  a_tag_with_href_and_content(
    blame,
    format_chapter_link(info.0, info.1),
    case info.1, direction {
      0, ">>" -> "Kapitel " <> ins(info.0) <> "  " <> direction
      _, ">>" -> "Kapitel " <> ins(info.0) <> "." <> ins(info.1) <> "  " <> direction
      0, "<<" -> direction <> " Kapitel " <> ins(info.0)
      _, "<<" -> direction <> " Kapitel " <> ins(info.0) <> "." <> ins(info.1)
      _, _ -> panic as "unknown direction"
    }
  )
}

fn info_2_left_menu(
  prev_info: Option(PageInfo)
) -> VXML {
  let blame = infra.blame_us("info_2_left_menu")
  let index_link_option = Some(a_tag_with_href_and_content(blame, "./index.html", "Inhaltsverzeichnis"))
  let ch_link_option = option.map(prev_info, info_2_link(blame, _, "<<"))

  V(
    blame,
    "LeftMenu",
    [BlamedAttribute(blame, "class", "menu-left")],
    option.values([index_link_option, ch_link_option]),
  )
}

fn info_2_right_menu(
  next_info: Option(PageInfo),
  homepage_url: String,
) -> VXML {
  let blame = infra.blame_us("info_2_right_menu")
  let course_homepage_link = Some(a_tag_with_href_and_content(blame, homepage_url, "zür Kursübersicht"))
  let ch_link_option = option.map(next_info, info_2_link(blame, _, ">>"))

  V(
    blame,
    "RightMenu",
    [BlamedAttribute(blame, "class", "menu-right")],
    option.values([course_homepage_link, ch_link_option]),
  )
}

fn infos_2_menu(
  infos: #(Option(PageInfo), Option(PageInfo)),
  homepage_url: String,
) -> VXML {
  V(
    infra.blame_us("infos_2_menu"),
    "Menu",
    [],
    [
      info_2_left_menu(infos.0),
      info_2_right_menu(infos.1, homepage_url),
    ]
  )
}

fn prepend_menu_element(
  node: VXML,
  chapter_no: Int,
  sub_no: Int,
  all_pages: List(PageInfo),
  homepage_url: String,
) -> VXML {
  let menu = infos_2_menu(
    get_prev_next_info(chapter_no, sub_no, all_pages),
    homepage_url,
  )
  infra.prepend_child(node, menu)
}

fn process_chapters(
  chapter: VXML,
  chapter_no: Int,
  all_pages: List(PageInfo),
  homepage_url: String,
) -> VXML {
  let chapter = prepend_menu_element(chapter, chapter_no, 0, all_pages, homepage_url)
  let assert V(_, _, _, children) = chapter
  let #(_, children) = list.map_fold(
    children,
    0,
    fn (acc, child) {
      case child {
        V(_, tag, _, _) if tag == "Sub" -> #(
          acc + 1,
          prepend_menu_element(child, chapter_no, acc + 1, all_pages, homepage_url)
        )
        _ -> #(
          acc,
          child,
        )
      }
    }
  )
  V(..chapter, children: children)
}

fn build_page_infos(root: VXML) -> List(PageInfo) {
  let chapters = infra.children_with_tag(root, "Chapter")
  list.index_fold(
    chapters,
    [],
    fn(acc, chapter, chapter_idx) {
      let chapter_no = chapter_idx + 1
      let subchapters = infra.children_with_tag(chapter, "Sub")
      let subchapters = list.index_map(
        subchapters,
        fn(_, sub_idx) { #(chapter_no, sub_idx + 1) }
      )
      list.flatten([acc, [#(chapter_no, 0)], subchapters])
    }
  )
}

fn at_root(root: VXML) -> Result(VXML, DesugaringError) {
  let assert V(_, "Document", _, children) = root
  let homepage_url = get_course_homepage(root)
  let all_pages = build_page_infos(root)
  let #(_, children) = list.map_fold(
    children,
    0,
    fn (acc, child) {
      case child {
        V(_, tag, _, _) if tag == "Chapter" -> #(
          acc + 1,
          process_chapters(child, acc + 1, all_pages, homepage_url)
        )
        _ -> #(
          acc,
          child,
        )
      }
    }
  )
  Ok(V(..root, children: children))
}

fn transform_factory(_: InnerParam) -> infra.DesugarerTransform {
  at_root
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "generate_ti3_menu"
const constructor = generate_ti3_menu

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// generate ti3 Menu navigation with left and right
/// menus containing previous/next chapter links,
/// index link, and course homepage link. The menu
/// is inserted after each Chapter and Sub element.
pub fn generate_ti3_menu() -> Desugarer {
  Desugarer(
    name,
    None,
    "
/// generate ti3 Menu navigation with left and right
/// menus containing previous/next chapter links,
/// index link, and course homepage link. The menu
/// is inserted after each Chapter and Sub element.
    ",
    case param_to_inner_param(Nil) {
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
  infra.assertive_tests_from_data_nil_param(name, assertive_tests_data(), constructor)
}
