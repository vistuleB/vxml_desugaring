import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugaringError} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn prepend_link(vxml: VXML, link_value: String, link_key: String) -> VXML {
  infra.prepend_attribute(vxml, BlamedAttribute(vxml.blame, link_key, link_value))
}

fn add_links_to_chapter(vxml: VXML, number: Int, num_chapters: Int) -> VXML {
  let assert True = number >= 1 && number <= num_chapters
  let prev_link = case number == 1 {
    True -> "/"
    False -> "/article/chapter" <> ins(number - 1)
  }
  let next_link = case number == num_chapters {
    True -> ""
    False -> "/article/chapter" <> ins(number + 1)
  }
  vxml
  |> prepend_link(next_link, "next-page")
  |> prepend_link(prev_link, "prev-page")
}

fn add_links_to_bootcamp(vxml: VXML, number: Int, num_bootcamps: Int) -> VXML {
  let assert True = number >= 1 && number <= num_bootcamps
  let prev_link = case number == num_bootcamps {
    True -> ""
    False -> "/article/bootcamp" <> ins(number + 1)
  }
  let next_link = case number == 1 {
    True -> "/"
    False -> "/article/bootcamp" <> ins(number - 1)
  }
  vxml
  |> prepend_link(next_link, "next-page")
  |> prepend_link(prev_link, "prev-page")
}

fn add_links_to_toc(vxml: VXML, num_bootcamps: Int, num_chapters: Int) -> VXML {
  let prev_link = case num_bootcamps > 0 {
    True -> "/article/bootcamp1"
    False -> ""
  }
  let next_link = case num_chapters > 0 {
    True -> "/article/chapter1"
    False -> ""
  }
  vxml
  |> prepend_link(next_link, "next-page")
  |> prepend_link(prev_link, "prev-page")
}

fn at_root(root: VXML) -> Result(VXML, DesugaringError) {
  let assert V(_, _, _, children) = root
  let chapters = infra.children_with_tag(root, "Chapter")
  let bootcamps = infra.children_with_tag(root, "Bootcamp")
  let assert [toc] = infra.children_with_tag(root, "TOC")

  let num_chapters = list.length(chapters)
  let num_bootcamps = list.length(bootcamps)

  let chapters = list.index_map(chapters, fn(c, i) {add_links_to_chapter(c, i + 1, num_chapters)})
  let bootcamps = list.index_map(bootcamps, fn(c, i) {add_links_to_bootcamp(c, i + 1, num_bootcamps)})
  let toc = add_links_to_toc(toc, num_bootcamps, num_chapters)

  let other_children = list.filter(children, fn(c) { !infra.is_v_and_tag_is_one_of(c, ["TOC", "Chapter", "Bootcamp"]) })

  Ok(V(..root, children: list.flatten([other_children, [toc], chapters, bootcamps])))
}

fn transform_factory(_: InnerParam) -> infra.DesugarerTransform {
  at_root
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "generate_lbp_prev_next_attributes"
const constructor = generate_lbp_prev_next_attributes

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
pub fn generate_lbp_prev_next_attributes() -> Desugarer {
  Desugarer(
    name,
    option.None,
    option.None,
    "...",
    case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    },
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestDataNoParam) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_no_param(name, assertive_tests_data(), constructor)
}