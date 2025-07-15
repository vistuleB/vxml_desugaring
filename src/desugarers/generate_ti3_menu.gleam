import gleam/list
import gleam/option

import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugaringError} as infra
import vxml.{type VXML, BlamedAttribute, BlamedContent, V, T}
import gleam/function

type ChapterInfo = #(Int, Int)  // (chapter_no, sub_no)

fn get_course_homepage(document: VXML) -> String {
  let default_attr = BlamedAttribute(infra.blame_us("get_course_homepage"), "course_homepage", "")

  infra.on_none_on_some(
    infra.v_attribute_with_key(document, "course_homepage"),
    default_attr,
    function.identity
  ).value
}

fn format_chapter_link(chapter_no: Int, sub_no: Int) -> String {
  "./" <> ins(chapter_no) <> "-" <> ins(sub_no) <> ".html"
}

fn build_chapter_info_list(root: VXML) -> List(ChapterInfo) {
  let chapters = infra.children_with_tag(root, "Chapter")

  list.index_fold(chapters, [], fn(acc, chapter, chapter_idx) {
    let chapter_no = chapter_idx + 1
    let subchapters = infra.children_with_tag(chapter, "Sub")

    let main_chapter = #(chapter_no, 0)
    let sub_chapters = list.index_map(subchapters, fn(_, sub_idx) {
      #(chapter_no, sub_idx + 1)
    })

    list.flatten([acc, [main_chapter], sub_chapters])
  })
}

fn get_prev_next_info(current_chapter: Int, current_sub: Int, all_chapters: List(ChapterInfo)) -> #(option.Option(ChapterInfo), option.Option(ChapterInfo)) {
  let current_info = #(current_chapter, current_sub)

  let current_idx = list.index_fold(all_chapters, option.None, fn(acc, chapter_info, idx) {
    case chapter_info == current_info {
      True -> option.Some(idx)
      False -> acc
    }
  })

  case current_idx {
    option.None -> #(option.None, option.None)
    option.Some(idx) -> {
      let prev_info = case idx {
        0 -> option.None
        _ -> infra.get_at(all_chapters, idx - 1) |> option.from_result
      }
      let next_info = infra.get_at(all_chapters, idx + 1) |> option.from_result
      #(prev_info, next_info)
    }
  }
}

fn construct_left_menu(prev_info: option.Option(ChapterInfo), is_first: Bool) -> VXML {
  let blame = infra.blame_us("construct_left_menu")

  let index_link = V(
    blame,
    "a",
    [BlamedAttribute(blame, "href", "./index.html")],
    // Index
    [T(blame, [BlamedContent(blame, "Inhaltsverzeichnis")])]
  )

  let links = case is_first {
    True -> [index_link]
    False -> {
      case prev_info {
        option.None -> [index_link]
        option.Some(#(prev_chapter, prev_sub)) -> [
          index_link,
          V(
            blame,
            "a",
            [BlamedAttribute(blame, "href", format_chapter_link(prev_chapter, prev_sub))],
            [T(blame, [BlamedContent(blame, case prev_sub {
              0 -> "<< Kapitel " <> ins(prev_chapter)
              _ -> "<< Kapitel " <> ins(prev_chapter) <> "." <> ins(prev_sub)
            })])]
          )
        ]
      }
    }
  }

  V(
    blame,
    "LeftMenu",
    [BlamedAttribute(blame, "class", "menu-left")],
    links
  )
}

fn construct_right_menu(next_info: option.Option(ChapterInfo), course_homepage: String) -> VXML {
  let blame = infra.blame_us("construct_right_menu")

  let course_link = V(
    blame,
    "a",
    [BlamedAttribute(blame, "href", course_homepage)],
    [T(blame, [BlamedContent(blame, "zur Kursübersicht")])]
  )

  let links = case next_info {
    option.None -> [course_link]
    option.Some(#(next_chapter, next_sub)) -> [
      course_link,
      V(
        blame,
        "a",
        [BlamedAttribute(blame, "href", format_chapter_link(next_chapter, next_sub))],
        [T(blame, [BlamedContent(blame, case next_sub {
          0 -> "Kapitel " <> ins(next_chapter) <> " >>"
          _ -> "Kapitel " <> ins(next_chapter) <> "." <> ins(next_sub) <> " >>"
        })])]
      )
    ]
  }

  V(
    blame,
    "RightMenu",
    [BlamedAttribute(blame, "class", "menu-right")],
    links
  )
}

fn construct_menu(prev_info: option.Option(ChapterInfo), next_info: option.Option(ChapterInfo), course_homepage: String, is_first: Bool) -> VXML {
  let blame = infra.blame_us("construct_menu")

  let left_menu = construct_left_menu(prev_info, is_first)
  let right_menu = construct_right_menu(next_info, course_homepage)

  V(
    blame,
    "Menu",
    [],
    [left_menu, right_menu]
  )
}

fn add_menu_to_node(node: VXML, chapter_no: Int, sub_no: Int, all_chapters: List(ChapterInfo), course_homepage: String) -> VXML {
  let #(prev_info, next_info) = get_prev_next_info(chapter_no, sub_no, all_chapters)
  let is_first = chapter_no == 1 && sub_no == 0
  let menu = construct_menu(prev_info, next_info, course_homepage, is_first)

  case node {
    V(blame, tag, attrs, children) -> V(blame, tag, attrs, [menu, ..children])
    T(_, _) -> node
  }
}

fn process_chapters(chapters: List(VXML), all_chapters: List(ChapterInfo), course_homepage: String) -> List(VXML) {
  list.index_map(chapters, fn(chapter, chapter_idx) {
    let chapter_no = chapter_idx + 1
    let subchapters = infra.children_with_tag(chapter, "Sub")
    let _other_children = list.filter(infra.get_children(chapter), fn(child) {
      !infra.is_v_and_tag_equals(child, "Sub")
    })

    // Add menu to main chapter
    let chapter_with_menu = add_menu_to_node(chapter, chapter_no, 0, all_chapters, course_homepage)

    // Process subchapters
    let processed_subchapters = list.index_map(subchapters, fn(subchapter, sub_idx) {
      let sub_no = sub_idx + 1
      add_menu_to_node(subchapter, chapter_no, sub_no, all_chapters, course_homepage)
    })

    // Reconstruct chapter with processed subchapters
    case chapter_with_menu {
      V(blame, tag, attrs, chapter_children) -> {
        let filtered_children = list.filter(chapter_children, fn(child) {
          !infra.is_v_and_tag_equals(child, "Sub")
        })
        V(blame, tag, attrs, list.append(filtered_children, processed_subchapters))
      }
      T(_, _) -> chapter_with_menu
    }
  })
}

fn at_root(root: VXML) -> Result(VXML, DesugaringError) {
  let assert V(blame, "Document", attrs, children) = root
  let all_chapters = build_chapter_info_list(root)
  let course_homepage = get_course_homepage(root)

  let chapters = infra.children_with_tag(root, "Chapter")
  let other_children = list.filter(children, fn(child) {
    !infra.is_v_and_tag_equals(child, "Chapter")
  })

  let processed_chapters = process_chapters(chapters, all_chapters, course_homepage)

  Ok(V(blame, "Document", attrs, list.append(other_children, processed_chapters)))
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
/// Generate ti3 Menu navigation
pub fn generate_ti3_menu() -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// Generate ti3 Menu navigation with left and right menus containing
/// previous/next chapter links, index link, and course homepage link.
/// The menu is inserted after each Chapter and Sub element.
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
