import gleeunit
import gleeunit/should
import infrastructure.{DoubleDollar}
import prefabricated_pipelines
import vxml.{T, BlamedContent}
import blamedlines.{Blame}

pub fn main() {
  gleeunit.main()
}

pub fn normalize_begin_end_align_adds_delimiters_when_missing_test() {
  let blame = Blame("test", 1, 0, [])
  let input_text = "Some text\n\\begin{align}\nx = 1\n\\end{align}\nMore text"
  let input_node = T(blame, [BlamedContent(blame, input_text)])

  let desugarer = prefabricated_pipelines.normalize_begin_end_align(DoubleDollar)

  let result = case desugarer.transform(input_node) {
    Ok(node) -> node
    Error(_) -> panic as "Transform failed"
  }

  let assert T(_, [BlamedContent(_, output_text)]) = result

  // should add $$ delimiters
  output_text
  |> should.equal("Some text\n$$\\begin{align}\nx = 1\n\\end{align}$$\nMore text")
}

pub fn normalize_begin_end_align_skips_when_delimiters_present_test() {
  let blame = Blame("test", 1, 0, [])
  let input_text = "Some text\n$$\n\\begin{align}\nx = 1\n\\end{align}\n$$\nMore text"
  let input_node = T(blame, [BlamedContent(blame, input_text)])

  let desugarer = prefabricated_pipelines.normalize_begin_end_align(DoubleDollar)

  let result = case desugarer.transform(input_node) {
    Ok(node) -> node
    Error(_) -> panic as "Transform failed"
  }

  let assert T(_, [BlamedContent(_, output_text)]) = result

  // Should NOT add additional delimiters
  output_text
  |> should.equal("Some text\n$$\n\\begin{align}\nx = 1\n\\end{align}\n$$\nMore text")
}

pub fn normalize_begin_end_align_handles_align_star_test() {
  let blame = Blame("test", 1, 0, [])
  let input_text = "\\begin{align*}\nx = 1\n\\end{align*}"
  let input_node = T(blame, [BlamedContent(blame, input_text)])

  let desugarer = prefabricated_pipelines.normalize_begin_end_align(DoubleDollar)

  let result = case desugarer.transform(input_node) {
    Ok(node) -> node
    Error(_) -> panic as "Transform failed"
  }

  let assert T(_, [BlamedContent(_, output_text)]) = result

  // should add $$ delimiters around align*
  output_text
  |> should.equal("$$\\begin{align*}\nx = 1\n\\end{align*}$$")
}

pub fn normalize_begin_end_align_multiple_occurrences_test() {
  let blame = Blame("test", 1, 0, [])
  let input_text = "\\begin{align}\nx = 1\n\\end{align}\n\nSome text\n\n\\begin{align*}\ny = 2\n\\end{align*}"
  let input_node = T(blame, [BlamedContent(blame, input_text)])

  let desugarer = prefabricated_pipelines.normalize_begin_end_align(DoubleDollar)

  let result = case desugarer.transform(input_node) {
    Ok(node) -> node
    Error(_) -> panic as "Transform failed"
  }

  let assert T(_, [BlamedContent(_, output_text)]) = result

  // should add $$ delimiters around both align blocks
  output_text
  |> should.equal("$$\\begin{align}\nx = 1\n\\end{align}$$\n\nSome text\n\n$$\\begin{align*}\ny = 2\n\\end{align*}$$")
}

pub fn normalize_begin_end_align_with_single_dollar_test() {
  let blame = Blame("test", 1, 0, [])
  let input_text = "\\begin{align}\nx = 1\n\\end{align}"
  let input_node = T(blame, [BlamedContent(blame, input_text)])

  let desugarer = prefabricated_pipelines.normalize_begin_end_align(infrastructure.SingleDollar)

  let result = case desugarer.transform(input_node) {
    Ok(node) -> node
    Error(_) -> panic as "Transform failed"
  }

  let assert T(_, [BlamedContent(_, output_text)]) = result

  // should add $ delimiters
  output_text
  |> should.equal("$\\begin{align}\nx = 1\n\\end{align}$")
}

pub fn normalize_begin_end_align_partial_delimiters_test() {
  let blame = Blame("test", 1, 0, [])
  let input_text = "$$\n\\begin{align}\nx = 1\n\\end{align}"
  let input_node = T(blame, [BlamedContent(blame, input_text)])

  let desugarer = prefabricated_pipelines.normalize_begin_end_align(DoubleDollar)

  let result = case desugarer.transform(input_node) {
    Ok(node) -> node
    Error(_) -> panic as "Transform failed"
  }

  let assert T(_, [BlamedContent(_, output_text)]) = result

  // should only add closing delimiter since opening is present
  output_text
  |> should.equal("$$\n\\begin{align}\nx = 1\n\\end{align}$$")
}
