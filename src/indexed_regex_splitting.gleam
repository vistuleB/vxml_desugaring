import blamedlines.{type Blame, Blame}
import gleam/list
import gleam/regexp.{type Regexp}
import gleam/string.{inspect as ins}
import vxml.{ type BlamedContent, type VXML, BlamedContent, T, V }
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

const regex_prefix_to_make_unescaped = "(?<!\\\\)(?:(?:\\\\\\\\)*)"

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

pub fn unescaped_suffix(suffix: String) -> String {
  regex_prefix_to_make_unescaped <> "(" <> suffix <> ")"
}

pub fn unescaped_suffix_indexed_regex(suffix: String) -> RegexWithIndexedGroup {
  suffix
  |> unescaped_suffix
  |> compile_into_indexed_group(0, 1)
}

pub fn l_m_r_1_3_indexed_regex(
  left: String,
  middle: String,
  right: String,
) -> RegexWithIndexedGroup {
  { "(" <> left <> ")(" <> middle <> ")(" <> right <> ")" }
  |> compile_into_indexed_group(1, 3)
}

pub fn l_m_r_1_3_indexed_regex_no_middle_par(
  left: String,
  middle: String,
  right: String,
) -> RegexWithIndexedGroup {
  { "(" <> left <> ")" <> middle <> "(" <> right <> ")" }
  |> compile_into_indexed_group(1, 3)
}

//********************
// splitting helpers
//********************

pub fn split_string_by_regex_with_indexed_group(
  content: String,
  indexed_regex: RegexWithIndexedGroup,
) -> List(String) {
  use <- infra.on_true_on_false(content == "", [""])
  let #(re, dropped_group, num_groups, pattern) = indexed_regex
  let splits = regexp.split(re, content)
  let num_matches: Int = { list.length(splits) - 1 } / { num_groups + 1 }
  case { num_matches * { num_groups + 1 } } + 1 == list.length(splits) {
    True -> Nil
    False -> panic as {
"pattern split failed:
  -- content: " <> content <> "[END]" <> "
  -- splits: " <> ins(splits) <> "
  -- num_groups: " <> ins(num_groups) <> "
  -- num_matches: " <> ins(num_matches) <> "
  -- pattern: " <> ins(pattern)
    }
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

// Helper function to calculate character positions
fn calculate_char_positions(splits: List(String)) -> List(Int) {
  list.index_fold(
    splits,
    #([], 0),
    fn(acc, split, _) {
      let #(positions, current_pos) = acc
      let new_pos = current_pos + string.length(split)
      #([current_pos, ..positions], new_pos)
    }
  )
  |> fn(result) { list.reverse(result.0) }
}

fn split_line_by_regex_with_indexed_group(
  line: BlamedContent,
  re: RegexWithIndexedGroup,
) -> List(EitherOr(BlamedContent, Blame)) {
  let BlamedContent(blame, content) = line
  
  // Track character position as we split
  let splits = split_string_by_regex_with_indexed_group(content, re)

  // Create a list of character positions for each split
  let char_positions = calculate_char_positions(splits)

  // Map each split to a BlamedContent with updated char_no
  list.index_map(
    splits,
    fn(split, idx) {
      let char_pos = infra.get_at(char_positions, idx)
      let assert Ok(pos) = char_pos
      let updated_blame = Blame(..blame, char_no: blame.char_no + pos)
      Either(BlamedContent(updated_blame, split))
    }
  )
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

pub fn split_by_regexes_with_indexed_group_nodemap(
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
