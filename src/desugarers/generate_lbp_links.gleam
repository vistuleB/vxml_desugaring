import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type DesugaringError, type Pipe, DesugarerDescription} as infra
import vxml.{type VXML, BlamedAttribute, V}

fn blame_us(note: String) -> Blame {
  Blame("generate_lbp_links:" <> note, -1, -1, [])
}

fn try_prepand_link(vxml: VXML, link_value: String, class: String) -> VXML {
  case link_value {
    "" -> vxml
    _ ->
      infra.prepend_child(
        vxml,
        V(
          blame_us(""),
          "a",
          [
            BlamedAttribute(blame_us(""), "class", class),
            BlamedAttribute(blame_us(""), "href", link_value),
          ],
          [],
        ),
      )
  }
}

fn map_chapters(chapter: #(VXML, Int), local_index: Int, length: Int) {
  let #(chapter_vxml, global_index) = chapter

  let #(prev_link, next_link) = case local_index, length {
    0, 1 -> #("/", "")
    0, _ -> #("/", "/article/chapter" <> ins(local_index + 2))
    a, _ if a == length - 1 -> #("/article/chapter" <> ins(local_index), "")
    _, _ -> #(
      "/article/chapter" <> ins(local_index),
      "/article/chapter" <> ins(local_index + 2),
    )
  }
  let new =
    chapter_vxml
    |> try_prepand_link(prev_link, "prev_page")
    |> try_prepand_link(next_link, "next_page")

  #(new, global_index)
}

fn map_bootcamps(bootcamp: #(VXML, Int), local_index: Int, length: Int) {
  let #(bootcamp_vxml, global_index) = bootcamp

  let #(prev_link, next_link) = case local_index {
    0 -> #("/article/bootcamp" <> ins(local_index + 2), "/")
    a if a == length - 1 -> #("", "/article/bootcamp" <> ins(local_index))
    _ -> #(
      "/article/bootcamp" <> ins(local_index + 2),
      "/article/bootcamp" <> ins(local_index),
    )
  }
  let new =
    bootcamp_vxml
    |> try_prepand_link(prev_link, "prev_page")
    |> try_prepand_link(next_link, "next_page")

  #(new, global_index)
}

fn transform(
  root: VXML,
) -> Result(VXML, DesugaringError) {
  let assert V(root_b, root_t, root_a, children) = root
  let chapters = infra.index_children_with_tag(root, "Chapter")
  let bootcamps = infra.index_children_with_tag(root, "Bootcamp")

  let toc = infra.index_children_with_tag(root, "TOCAuthorSuppliedContents")
  let assert [#(toc, _)] = toc

  let #(chapters, bootcamps, toc) = case
    list.is_empty(chapters),
    list.is_empty(bootcamps)
  {
    True, True -> #([], [], toc)
    False, False -> {
      let chapters =
        chapters
        |> list.index_map(fn(c, i) { map_chapters(c, i, list.length(chapters)) })
      let bootcamps =
        bootcamps
        |> list.index_map(fn(c, i) {
          map_bootcamps(c, i, list.length(bootcamps))
        })

      let toc =
        toc
        |> try_prepand_link("/article/bootcamp1", "prev_page")
        |> try_prepand_link("/article/chapter1", "next_page")

      #(chapters, bootcamps, toc)
    }
    True, False -> {
      let bootcamps =
        bootcamps
        |> list.index_map(fn(c, i) {
          map_bootcamps(c, i, list.length(bootcamps))
        })

      let toc =
        toc
        |> try_prepand_link("/article/bootcamp1", "prev_page")

      #([], bootcamps, toc)
    }
    False, True -> {
      let chapters =
        chapters
        |> list.index_map(fn(c, i) { map_chapters(c, i, list.length(chapters)) })

      let toc =
        toc
        |> try_prepand_link("/article/chapter1", "next_page")

      #(chapters, bootcamps, toc)
    }
  }

  let children =
    children
    |> list.index_map(fn(vxml, global_index) {
      let assert V(_, tag, _, _) = vxml
      let chapter =
        list.find_map(chapters, fn(c) {
          let #(vxml_updated, idx) = c

          case idx == global_index {
            True -> Ok(vxml_updated)
            False -> Error(Nil)
          }
        })
      use _ <- infra.on_error_on_ok(over: chapter, with_on_ok: fn(c) { c })

      let bootcamp =
        list.find_map(bootcamps, fn(c) {
          let #(vxml, idx) = c
          case idx == global_index {
            True -> Ok(vxml)
            False -> Error(Nil)
          }
        })
      use _ <- infra.on_error_on_ok(over: bootcamp, with_on_ok: fn(c) { c })

      use <- infra.on_true_on_false(
        over: tag == "TOCAuthorSuppliedContents",
        with_on_true: toc,
      )

      vxml
    })

  Ok(V(root_b, root_t, root_a, children))
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> infra.Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// generates navigation links for LBP content (chapters and bootcamps)
pub fn generate_lbp_links() -> Pipe {
  infra.Pipe(
    description: DesugarerDescription(
      desugarer_name: "generate_lbp_links",
      stringified_param: option.None,
      general_description: "
/// generates navigation links for LBP content (chapters and bootcamps)
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}