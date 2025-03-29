import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/regexp.{type Regexp}
import gleam/string
import vxml_parser.{ type BlamedContent, type VXML, BlamedContent, T, V }
import infrastructure.{type EitherOr, Or, Either, type DesugaringError } as infra

//**************************************************************
//* RegexWithIndexedGroup
//**************************************************************

pub type RegexWithIndexedGroup =
  #(Regexp, Int,         Int,          String)
//           ↖            ↖             ↖
//          index of     total num     original string
//          splitting    groups        used to construct Regex
//          group

//********
// RegexWithIndexedGroup constructor helpers
//********

const regex_prefix_to_make_unescaped = "(?<!\\\\)((?:\\\\\\\\)*)"

fn assert_ok_regexp_from_string(s: String) -> regexp.Regexp {
  let assert Ok(re) = regexp.from_string(s)
  re
}

fn compile_into_indexed_group(
  pattern: String,
  zero_indexed_group: Int,
  num_groups: Int,
) -> RegexWithIndexedGroup {
  let assert True = zero_indexed_group + 1 <= num_groups
  #(
    pattern |> assert_ok_regexp_from_string,
    zero_indexed_group,
    num_groups,
    pattern,
  )
}

//********
// RegexWithIndexedGroup public constructors
//********

pub fn unescaped_suffix_indexed_regex(suffix: String) -> RegexWithIndexedGroup {
  { regex_prefix_to_make_unescaped <> "(" <> suffix <> ")" }
  |> compile_into_indexed_group(1, 2)
}

pub fn l_m_r_1_3_indexed_regex(
  left: String,
  middle: String,
  right: String,
) -> RegexWithIndexedGroup {
  { "(" <> left <> ")(" <> middle <> ")(" <> right <> ")" }
  |> compile_into_indexed_group(1, 3)
}

//********************
// splitting helpers
//********************

pub fn split_string_by_regex_with_indexed_group(
  content: String,
  indexed_regex: RegexWithIndexedGroup,
) -> List(String) {
  let #(re, dropped_group, num_groups, pattern) = indexed_regex
  let splits = regexp.split(re, content)
  let num_matches: Int = { list.length(splits) - 1 } / { num_groups + 1 }
  case { num_matches * { num_groups + 1 } } + 1 == list.length(splits) {
    True -> Nil
    False -> panic as { "pattern split failed: " <> pattern <> "[END]" }
  }
  list.index_map(
    splits,
    fn(split, index: Int) {
      case index % { num_groups + 1 } == dropped_group + 1 {
        False -> Either(split)
        True -> Or(Nil)
      }
    }
  )
  |> infra.regroup_eithers
  |> infra.remove_ors_unwrap_eithers
  |> list.map(string.join(_, ""))
}

fn split_line_by_regex_with_indexed_group(
  line: BlamedContent,
  re: RegexWithIndexedGroup,
) -> List(EitherOr(BlamedContent, Blame)) {
  let BlamedContent(blame, content) = line
  split_string_by_regex_with_indexed_group(content, re)
  |> list.map(fn(thing) { Either(BlamedContent(blame, thing)) })
  |> list.intersperse(Or(blame))
}

fn replace_indexed_group_by_tag_in_lines(
  lines: List(BlamedContent),
  re: RegexWithIndexedGroup,
  tag: String,
) -> List(VXML) {
  lines
  |> list.map(split_line_by_regex_with_indexed_group(_, re))
  |> list.flatten
  |> infra.regroup_eithers
  |> infra.map_either_ors(
    fn(blamed_contents) {
      let assert [BlamedContent(blame, _), ..] = blamed_contents
      T(blame, blamed_contents)
    },
    fn(blame) { V(blame, tag, [], []) },
  )
}

fn replace_indexed_group_by_tag_in_node(
  node: VXML,
  re: RegexWithIndexedGroup,
  tag: String,
) -> List(VXML) {
  case node {
    V(_, _, _, _) -> [node]
    T(_, lines) -> {
      replace_indexed_group_by_tag_in_lines(lines, re, tag)
    }
  }
}

fn replace_indexed_group_by_tag_in_nodes(
  nodes: List(VXML),
  re: RegexWithIndexedGroup,
  tag: String,
) -> List(VXML) {
  nodes
  |> list.map(replace_indexed_group_by_tag_in_node(_, re, tag))
  |> list.flatten
}

//********************
// public splitters
//********************

pub fn split_by_regexes_with_indexed_group_node_to_nodes_transform(
  node: VXML,
  rules: List(#(RegexWithIndexedGroup, String)),
) -> Result(List(VXML), DesugaringError) {
  list.fold(
    rules,
    [node],
    fn (nodes, rule) -> List(VXML) {
      let #(regex, tag) = rule
      replace_indexed_group_by_tag_in_nodes(nodes, regex, tag)
    }
  )
  |> Ok
}
