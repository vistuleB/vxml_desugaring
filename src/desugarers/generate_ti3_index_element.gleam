import gleam/list
import gleam/option.{Some,None}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugaringError} as infra
import vxml.{type VXML, type BlamedContent, BlamedAttribute, BlamedContent, V, T}

type ChapterNo = Int
type SubChapterNo = Int
type ChapterTitle = String
type SubchapterTitle = String

fn extract_chapter_title(chapter: VXML) -> ChapterTitle {
  chapter
  |> infra.unique_child_with_tag("ChapterTitle")
  |> result.map(fn(chapter_title) {
    let assert V(_, _, _, children) = chapter_title
    let assert [T(_, contents), ..] = children
    contents
    |> list.map(fn(blamed_content: BlamedContent) { blamed_content.content })
    |> string.join("")
  })
  |> result.unwrap("no chapter title")
}

fn chapters_number_title(root: VXML) -> List(#(VXML, ChapterNo, ChapterTitle)) {
  root
  |> infra.index_children_with_tag("Chapter")
  |> list.map(fn(tup: #(VXML, Int)) {
    // increment index by 1 so it starts from 1 instead of 0
    #(tup.0, tup.1 + 1, extract_chapter_title(tup.0))
  })
}

fn extract_subchapter_title(chapter: VXML) -> List(#(SubChapterNo, SubchapterTitle)) {
  chapter
  |> infra.index_children_with_tag("Sub")
  |> list.map(fn(sub: #(VXML, Int)) {
      let subchapter_title =
        sub.0
        |> infra.unique_child_with_tag("SubTitle")
        |> result.map(fn(subtitle) {
          let assert V(_, _, _, children) = subtitle
          let assert [T(_, contents), ..] = children
          contents
          |> list.map(fn(blamed_content: BlamedContent) { blamed_content.content })
          |> string.join("")
        })
        |> result.unwrap("No subchapter title")

      // increment index by 1 so it starts from 1 instead of 0
      #(sub.1 + 1, subchapter_title)
  })
}

fn all_subchapters(chapters: List(#(VXML, ChapterNo, ChapterTitle))) -> List(#(ChapterNo, ChapterTitle, List(#(SubChapterNo, SubchapterTitle)))) {
  chapters
  |> list.map(fn(chapter: #(VXML, Int, String)) {
    chapter.0
    |> extract_subchapter_title
    |> fn(subchapters) {
      #(chapter.1, chapter.2, subchapters)
    }
 })
}

fn construct_subchapter_item(subchapter_title: String, subchapter_number: Int, chapter_number: Int) -> VXML {
  let blame = infra.blame_us("construct_index")
  V(
    blame,
    "li",
    [],
    [
      T(blame, [BlamedContent(blame, ins(chapter_number) <> "." <> ins(subchapter_number) <> " - ")]),
      V(
        blame,
        "a",
        [BlamedAttribute(blame, "href", "./" <> ins(chapter_number) <> "-" <> ins(subchapter_number) <> ".html")],
        [T(blame, [BlamedContent(blame, subchapter_title)])]
      )
    ]
  )
}

fn construct_chapter_item(chapter_number: Int, chapter_title: String, subchapters: List(#(SubChapterNo, SubchapterTitle))) -> VXML {
  let blame = infra.blame_us("construct_index")
  let subchapters_ol = case subchapters {
    [] -> []
    _ -> [
      V(
        blame,
        "ol",
        [BlamedAttribute(blame, "class", "index__list__subchapter")],
        list.map(subchapters, fn(subchapter) {
          let #(subchapter_number, subchapter_title) = subchapter
          construct_subchapter_item(subchapter_title, subchapter_number, chapter_number)
        })
      )
    ]
  }

  V(
    blame,
    "li",
    [BlamedAttribute(blame, "class", "index__list__chapter")],
    list.flatten([
      [
        T(blame, [BlamedContent(blame, ins(chapter_number) <> " - ")]),
        V(
          blame,
          "a",
          [BlamedAttribute(blame, "href", "./" <> ins(chapter_number) <> "-0" <> ".html")],
          [T(blame, [BlamedContent(blame, chapter_title)])]
        )
      ],
      subchapters_ol
    ])
  )
}

fn construct_header(document: VXML) -> VXML {
  let blame = infra.blame_us("construct_header")

  let title =
    case infra.v_attribute_with_key(document, "title") {
      None -> "no title"
      Some(x) -> x.value
    }

  let program =
    case infra.v_attribute_with_key(document, "program") {
      None -> "no program"
      Some(x) -> x.value
    }

  let institution =
    case infra.v_attribute_with_key(document, "institution") {
      None -> "no institution"
      Some(x) -> x.value
    }

  let lecturer =
    case infra.v_attribute_with_key(document, "lecturer") {
      None -> "no lecturer"
      Some(x) -> x.value
    }

  V(
    blame,
    "header",
    [BlamedAttribute(blame, "class", "main-column-width index__header")],
    [
      V(
        blame,
        "h1",
        [BlamedAttribute(blame, "class", "index__header__title")],
        [T(blame, [BlamedContent(blame, title)])]
      ),
      V(
        blame,
        "span",
        [BlamedAttribute(blame, "class", "index__header__subtitle")],
        [T(blame, [BlamedContent(blame, program)])]
      ),
      V(
        blame,
        "span",
        [BlamedAttribute(blame, "class", "index__header__subtitle")],
        [T(blame, [BlamedContent(blame, lecturer <> ", " <> institution)])]
      )
    ]
  )
}

fn construct_index(chapters: List(#(ChapterNo, ChapterTitle, List(#(SubChapterNo, SubchapterTitle))))) -> VXML {
  let blame = infra.blame_us("construct_index")
  V(
    blame,
    "section",
    [BlamedAttribute(blame, "class", "main-column-width")],
    [
      V(
        blame,
        "ol",
        [BlamedAttribute(blame, "class", "index__list")],
        list.map(chapters, fn(chapter) {
          let #(chapter_number, chapter_title, subchapters) = chapter
          construct_chapter_item(chapter_number, chapter_title, subchapters)
        })
      )
    ]
  )
}

fn at_root(root: VXML) -> Result(VXML, DesugaringError) {
  let assert V(_, "Document", _attrs, _children) = root
  let header_node = construct_header(root)
  let index_list_node =
        root
          |> chapters_number_title
          |> all_subchapters
          |> construct_index

  let index_node = V(
    infra.blame_us("construct_index"),
    "Index",
    [],
    [header_node, index_list_node]
  )

  infra.prepend_child(root, index_node)
  |> Ok
}

fn transform_factory(_: InnerParam) -> infra.DesugarerTransform {
  at_root
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "generate_ti3_index_element"
const constructor = generate_ti3_index_element

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Generate ti3 Index element
pub fn generate_ti3_index_element() -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// Generate ti3 Index element
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
