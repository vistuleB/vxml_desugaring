import desugarers/add_attributes.{add_attributes_desugarer}
import desugarers/break_up_text_by_double_dollars.{
  break_up_text_by_double_dollars_desugarer,
}
import desugarers/insert_indent.{insert_indent_desugarer}
import desugarers/insert_indent_v1.{insert_indent_v1_desugarer}
import desugarers/pair_double_dollars_together.{
  pair_double_dollars_together_desugarer,
}
import desugarers/remove_tag.{remove_tag_desugarer}
import desugarers/remove_vertical_chunks_around_single_children.{
  remove_vertical_chunks_around_single_children_desugarer,
}
import desugarers/remove_vertical_chunks_with_no_text_child.{
  remove_vertical_chunks_with_no_text_child_desugarer,
}
import desugarers/remove_writerly_blurb_tags_around_text_nodes.{
  remove_writerly_blurb_tags_around_text_nodes_desugarer,
}
import desugarers/split_content_by_low_level_delimiters.{
  split_content_by_low_level_delimiters_desugarer,
}
import desugarers/split_delimiters_chunks.{split_delimiters_chunks_desugarer}
import desugarers/split_vertical_chunks.{split_vertical_chunks_desugarer}
import desugarers/wrap_element_children.{wrap_element_children_desugarer}
import desugarers/wrap_elements_by_blankline.{
  wrap_elements_by_blankline_desugarer,
}
import desugarers/wrap_math_with_no_break.{wrap_math_with_no_break_desugarer}
import gleam/option.{type Option, Some}
import gleam/string
import infrastructure.{type DesugaringError}
import vxml_parser.{type VXML}

const ins = string.inspect

type Desugarer =
  fn(VXML) -> Result(VXML, DesugaringError)

pub type DesugarerDescription {
  DesugarerDescription(
    function_name: String,
    extra: Option(String),
    general_description: String,
  )
}

pub type Pipeline =
  List(#(DesugarerDescription, Desugarer))

pub fn add_attributes_pipe(extra) {
  #(
    DesugarerDescription("add_attributes_desugarer", Some(ins(extra)), ""),
    fn(x) { add_attributes_desugarer(x, extra) },
  )
}

pub fn remove_writerly_blurb_tags_around_text_nodes_pipe() {
  #(
    DesugarerDescription(
      "remove_writerly_blurb_tags_around_text_nodes_desugarer",
      option.None,
      "",
    ),
    fn(x) { remove_writerly_blurb_tags_around_text_nodes_desugarer(x) },
  )
}

pub fn break_up_text_by_double_dollars_pipe() {
  #(
    DesugarerDescription(
      "break_up_text_by_double_dollars_desugarer",
      option.None,
      "",
    ),
    fn(x) { break_up_text_by_double_dollars_desugarer(x) },
  )
}

pub fn remove_tag_pipe(tags: List(String)) {
  #(
    DesugarerDescription(
      "remove_tag_desugarer",
      option.None,
      "removes V-nodes whose tags come from the specified list",
    ),
    fn(x) { remove_tag_desugarer(x, tags) },
  )
}

pub fn insert_indent_pipe() {
  #(
    DesugarerDescription(
      "insert_indent_desugarer",
      option.None,
      "add 'insert true' attributes to VerticalChunk nodes\nthat immediately follow another VerticalChunk node",
    ),
    fn(x) { insert_indent_desugarer(x) },
  )
}

pub fn insert_indent_v1_pipe() {
  #(
    DesugarerDescription(
      "insert_indent_v1_desugarer",
      option.None,
      "insert <> Indent nodes around text nodes\nwhose previous sibling is a text node",
    ),
    fn(x) { insert_indent_v1_desugarer(x) },
  )
}

pub fn pair_double_dollars_together_pipe() {
  #(
    DesugarerDescription(
      "pair_double_dollars_together_desugarer",
      option.None,
      "",
    ),
    fn(x) { pair_double_dollars_together_desugarer(x) },
  )
}

pub fn wrap_elements_by_blankline_pipe(extra) {
  #(
    DesugarerDescription(
      "wrap_elements_by_blankline_desugarer",
      Some(ins(extra)),
      "",
    ),
    fn(x) { wrap_elements_by_blankline_desugarer(x, extra) },
  )
}

pub fn split_vertical_chunks_pipe() {
  #(
    DesugarerDescription("split_vertical_chunks_desugarer", option.None, ""),
    fn(x) { split_vertical_chunks_desugarer(x) },
  )
}

pub fn wrap_element_children_pipe(extra) -> #(DesugarerDescription, Desugarer) {
  #(DesugarerDescription("wrap_element_children", Some(ins(extra)), ""), fn(x) {
    wrap_element_children_desugarer(x, extra)
  })
}

pub fn remove_vertical_chunks_around_single_children_pipe() {
  #(
    DesugarerDescription(
      "remove_vertical_chunks_around_single_children_desugarer",
      option.None,
      "",
    ),
    fn(x) { remove_vertical_chunks_around_single_children_desugarer(x) },
  )
}

pub fn split_delimiters_chunks_pipe(extra) {
  #(
    DesugarerDescription(
      "split_delimiters_chunks_desugarer",
      Some(ins(extra)),
      "",
    ),
    fn(x) { split_delimiters_chunks_desugarer(x, extra) },
  )
}

pub fn split_content_by_low_level_delimiters_pipe() {
  #(
    DesugarerDescription(
      "split_content_by_low_level_delimiters_desugarer",
      option.None,
      "",
    ),
    fn(x) { split_content_by_low_level_delimiters_desugarer(x) },
  )
}

pub fn wrap_math_with_no_break_pipe() {
  #(
    DesugarerDescription("wrap_math_with_no_break_pipe", option.None, ""),
    fn(x) { wrap_math_with_no_break_desugarer(x) },
  )
}

pub fn remove_vertical_chunks_with_no_text_child_pipe() {
  #(
    DesugarerDescription(
      "remove_vertical_chunks_with_no_text_child_pipe",
      option.None,
      "",
    ),
    fn(x) { remove_vertical_chunks_with_no_text_child_desugarer(x) },
  )
}
