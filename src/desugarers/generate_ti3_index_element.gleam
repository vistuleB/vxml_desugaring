import gleam/list
import gleam/option
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, type BlamedContent, BlamedAttribute, BlamedContent, V, T}
import gleam/function

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
  |> result.unwrap("")
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
  let default_title_attr = BlamedAttribute(
    blame: infra.blame_us("generate_ti3_index_element - no title attr of Sub found"),
    key: "title",
    value: ""
  )
  chapter
  |> infra.index_children_with_tag("Sub")
  |> list.map(fn(sub: #(VXML, Int)) {
      let subchapter_title =
        infra.on_none_on_some(
          infra.v_attribute_with_key(sub.0, "title"),
          default_title_attr,
          function.identity
        ).value

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
        [BlamedAttribute(blame, "href", "./ch" <> ins(chapter_number) <> "-" <> ins(subchapter_number) <> ".html")],
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
          [BlamedAttribute(blame, "href", "./ch" <> ins(chapter_number) <> ".html")],
          [T(blame, [BlamedContent(blame, chapter_title)])]
        )
      ],
      subchapters_ol
    ])
  )
}

fn construct_header(document: VXML) -> VXML {
  let blame = infra.blame_us("construct_header")
  let default_attr = BlamedAttribute(blame, "key", "")

  let title = infra.on_none_on_some(
    infra.v_attribute_with_key(document, "title"),
    default_attr,
    function.identity
  ).value

  let program = infra.on_none_on_some(
    infra.v_attribute_with_key(document, "program"),
    default_attr,
    function.identity
  ).value

  let institution = infra.on_none_on_some(
    infra.v_attribute_with_key(document, "institution"),
    default_attr,
    function.identity
  ).value

  let lecturer = infra.on_none_on_some(
    infra.v_attribute_with_key(document, "lecturer"),
    default_attr,
    function.identity
  ).value

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

fn desugarer_factory() -> infra.Desugarer {
  at_root
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

pub const desugarer_name = "generate_ti3_index_element"
pub const desugarer_pipe = generate_ti3_index_element

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// Generate ti3 Index element
pub fn generate_ti3_index_element() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.None,
      general_description: "
/// Generate ti3 Index element
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(_) -> desugarer_factory()
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Nil)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_nil_param(desugarer_name, assertive_tests_data(), desugarer_pipe)
}
