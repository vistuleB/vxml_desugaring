import gleam/io
import gleam/pair
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe,
  DesugarerDescription, DesugaringError,
} as infra
import blamedlines.{type Blame, Blame}
import vxml_parser.{type VXML, V, BlamedAttribute}

const ins = string.inspect

fn blame_us(note: String) -> Blame {
  Blame("generate_lbp_toc:" <> note, -1, [])
}

fn chapter_link(chapter_link_component_name : String, item: VXML, count: Int) -> Result(VXML, DesugaringError) {
  let tp = case infra.tag_equals(item, "Chapter") {
    True -> "chapter"
    False -> {
      let assert True = infra.tag_equals(item, "Bootcamp")
      "bootcamp"
    }
  }

  let item_blame = infra.get_blame(item)

  use label_attr <- infra.on_none_on_some(
    infra.get_attribute_by_name(item, "title"),
    with_on_none: Error(DesugaringError(item_blame, tp <> " missing title attribute"))
  )

  let on_mobile_attr = case infra.get_attribute_by_name(item, "on_mobile") {
    Some(attr) -> attr
    None -> label_attr
  }

  Ok(V(
    item_blame,
    chapter_link_component_name,
    [
      BlamedAttribute(blame_us("L41"), "article_type", ins(count)),
      BlamedAttribute(label_attr.blame, "label", label_attr.value),
      BlamedAttribute(on_mobile_attr.blame, "on_mobile", on_mobile_attr.value),
      BlamedAttribute(blame_us("L44"), "href", tp <> ins(count)),
    ],
    []
  ))
}

fn type_of_chapters_title(
  type_of_chapters_title_component_name: String,
  label: String,
) -> VXML {
  V(
    blame_us("L52"),
    type_of_chapters_title_component_name,
    [
      BlamedAttribute(blame_us("L57"), "label", label)
    ],
    []
  )
}

fn div_with_id_title_and_menu_items(
  type_of_chapters_title_component_name: String,
  id: String,
  title_label: String,
  menu_items: List(VXML)
) -> VXML {
  V(
    blame_us("87"),
    "div",
    [
      BlamedAttribute(blame_us("L72"), "id", id)
    ],
    [
      type_of_chapters_title(
        type_of_chapters_title_component_name,
        title_label
      ),
      V(
        blame_us("L95"),
        "ul",
        [],
        menu_items
      )
    ]
  )
}

fn try_prepand_link(vxml: VXML, link_value: String, class: String) -> VXML {
  case link_value {
    "" -> vxml
    _ -> infra.prepend_child(
          vxml,
          V(
            blame_us(""), 
            "a", 
            [
              BlamedAttribute(blame_us(""), "class", class),
              BlamedAttribute(blame_us(""), "href", link_value),
            ],
            []
          )
        )
  }
}

fn map_chapters(chapter: #(VXML, Int), local_index: Int, length: Int) {
    
    let #(chapter_vxml, global_index) = chapter

    let #(prev_link, next_link) = case local_index {
      0 -> #("/", "/article/chapter" <> ins(local_index + 2))
      a if a == length - 1 -> #("/article/chapter" <> ins(local_index), "")  
      _ -> #("/article/chapter" <> ins(local_index), "/article/chapter" <> ins(local_index + 2))  
    }
    let new = chapter_vxml |> try_prepand_link(prev_link, "prev_page") |> try_prepand_link(next_link, "next_page")

    #(new, global_index)
}

fn map_bootcamps(bootcamp: #(VXML, Int), local_index: Int, length: Int) {
    
    let #(bootcamp_vxml, global_index) = bootcamp

    let #(prev_link, next_link) = case local_index {
      0 -> #("/article/bootcamp" <> ins(local_index + 2), "/")
      a if a == length - 1 -> #("", "/article/bootcamp" <> ins(local_index))  
      _ -> #("/article/bootcamp" <> ins(local_index + 2), "/article/bootcamp" <> ins(local_index))  
    }
    let new = bootcamp_vxml |> try_prepand_link(prev_link, "prev_page") |> try_prepand_link(next_link, "next_page")

    #(new, global_index)
}

fn the_desugarer(
  root: VXML
) -> Result(VXML, DesugaringError) {
 
  let assert V(root_b, root_t, root_a, children) = root
  let chapters =  infra.index_children_with_tag(root, "Chapter")
  let bootcamps = infra.index_children_with_tag(root, "Bootcamp")

  let toc = infra.index_children_with_tag(root, "TOCAuthorSuppliedContent")
  let assert [#(toc, _)] = toc

  let chapters = chapters
    |> list.index_map(fn(c, i){ map_chapters(c, i, list.length(chapters)) })
  let bootcamps = bootcamps
    |> list.index_map(fn(c, i){ map_bootcamps(c, i, list.length(bootcamps)) })

  let toc = toc 
  |> try_prepand_link("/article/bootcamp1", "prev_page")
  |> try_prepand_link("/article/chapter" <> ins(list.length(chapters)), "next_page")
  

  let children = children |> list.index_map(fn(vxml, global_index){
      let assert V(_, tag, _, _) = vxml
      let chapter = list.find_map(chapters, fn(c) { 
        let #(vxml_updated, idx) = c

        case idx == global_index {
          True -> Ok(vxml_updated)
          False -> Error(Nil)
        }
      })
      use _ <- infra.on_error_on_ok( 
        over: chapter,
        with_on_ok: fn(c) { c },
      )

      let bootcamp = list.find_map(bootcamps, fn(c) { 
        let #(vxml, idx) = c
        case idx == global_index {
          True -> Ok(vxml)
          False -> Error(Nil)
        }
      })
      use _ <- infra.on_error_on_ok( 
        over: bootcamp,
        with_on_ok: fn(c) { c },
      )

      use <- infra.on_true_on_false( 
        over: tag == "TOCAuthorSuppliedContent",
        with_on_true: toc,
      )

      vxml
    }
  )

  Ok(V(root_b, root_t, root_a, children))
}

pub fn generate_lbp_links() -> Pipe {
  infra.Pipe(
    DesugarerDescription("generate_lbp_links", option.None, "..."),
    fn (vxml) {
      the_desugarer(
        vxml
      )
    },
  )
}
