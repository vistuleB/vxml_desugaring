import gleam/dict.{type Dict}
import blamedlines.{type Blame, Blame}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/string
import vxml_parser.{type BlamedContent, type VXML, BlamedContent, T, V, type BlamedAttribute}

const ins = string.inspect

pub fn trim_starting_spaces_except_first_line(vxml: VXML) {
  let assert T(blame, lines) = vxml
  let assert [first_line, ..rest] = lines
  let updated_rest = rest |> list.map(fn(line) { 
    BlamedContent(..line, content: string.trim_start(line.content)) 
  })

  T(blame, [first_line, ..updated_rest])
}

pub fn trim_ending_spaces_except_last_line(vxml: VXML) {
  let assert T(blame, lines) = vxml
  let assert [last_line, ..rest] = lines |> list.reverse()
  let updated_rest = rest |> list.map(fn(line) { 
    BlamedContent(..line, content: string.trim_end(line.content)) 
  }) 

  T(blame, list.reverse([last_line, ..updated_rest]))
}

fn map_with_special_first_last_internal(l: List(a), fun: fn(a, Bool, Bool) -> b) -> List(b) {
 case l {
    [] -> []
    [last] -> {
      [fun(last, False, True)]
    }
    [el, ..rest] -> {
      [fun(el, False, False), ..map_with_special_first_last_internal(rest, fun)]
    }
 }
}


pub fn map_with_special_first_last(l: List(a), fun: fn(a, Bool, Bool) -> b) -> List(b) {
  case l {
    [] -> []
    [one] -> {
      [fun(one, True, True)]
    }
    [first, ..rest] -> {
      [fun(first, True, False), ..map_with_special_first_last_internal(rest, fun)]
    }
  }
}

pub fn is_singleton(z: List(a)) -> Bool {
  case z {
    [_] -> True
    _ -> False
  }
}

pub fn on_false_on_true(
  over condition: Bool,
  with_on_false f1: b,
  with_on_true f2: fn() -> b,
) -> b {
  case condition {
    False -> f1
    True -> f2()
  }
}

pub fn on_true_on_false(
  over condition: Bool,
  with_on_true f1: b,
  with_on_false f2: fn() -> b,
) -> b {
  case condition {
    True -> f1
    False -> f2()
  }
}

pub fn on_lazy_true_on_false(
  over condition: Bool,
  with_on_true f1: fn() -> b,
  with_on_false f2: fn() -> b,
) -> b {
  case condition {
    True -> f1()
    False -> f2()
  }
}

pub fn on_lazy_false_on_true(
  over condition: Bool,
  with_on_false f1: fn() -> b,
  with_on_true f2: fn() -> b,
) -> b {
  case condition {
    False -> f1()
    True -> f2()
  }
}

pub fn on_none_on_some(
  over option: Option(a),
  with_on_none f1: b,
  with_on_some f2: fn(a) -> b,
) -> b {
  case option {
    None -> f1
    Some(z) -> f2(z)
  }
}

pub fn on_some_on_none(
  over option: Option(a),
  with_on_some f2: fn(a) -> b,
  with_on_none f1: b,
) -> b {
  case option {
    None -> f1
    Some(z) -> f2(z)
  }
}

pub fn on_error_on_ok(
  over res: Result(a, b),
  with_on_error f1: fn(b) -> c,
  with_on_ok f2: fn(a) -> c,
) -> c {
  case res {
    Error(e) -> f1(e)
    Ok(r) -> f2(r)
  }
}

pub fn on_empty_on_nonempty(
  l: List(a),
  f1: c,
  f2: fn(a, List(a)) -> c,
) -> c {
  case l {
    [] -> f1
    [first, ..rest] -> f2(first, rest)
  }
}

pub fn on_lazy_empty_on_nonempty(
  l: List(a),
  f1: fn() -> c,
  f2: fn(a, List(a)) -> c,
) -> c {
  case l {
    [] -> f1()
    [first, ..rest] -> f2(first, rest)
  }
}

pub fn on_v_on_t(
  node: VXML,
  f1: fn(Blame, String, List(BlamedAttribute), List(VXML)) -> c,
  f2: fn(Blame, List(BlamedContent)) -> c,
) -> c {
  case node {
    V(blame, tag, attributes, children) -> f1(blame, tag, attributes, children)
    T(blame, blamed_contents) -> f2(blame, blamed_contents)
  }
}

pub fn on_t_on_v(
  node: VXML,
  f1: fn(Blame, List(BlamedContent)) -> c,
  f2: fn(Blame, String, List(BlamedAttribute), List(VXML)) -> c,
) -> c {
  case node {
    T(blame, blamed_contents) -> f1(blame, blamed_contents)
    V(blame, tag, attributes, children) -> f2(blame, tag, attributes, children)
  }
}

pub fn on_v_identity_on_t(
  node: VXML,
  f2: fn(Blame, List(BlamedContent)) -> VXML
) -> VXML {
  case node {
    V(_, _, _, _) -> node
    T(blame, blamed_contents) -> f2(blame, blamed_contents)
  }
}

pub fn io_debug_digests(
  vxmls: List(VXML),
  announce: String,
) -> List(VXML) {
  io.print(announce <> ": ")
  list.each(vxmls, fn(vxml) { io.print(digest(vxml)) })
  io.println("")
  vxmls
}

pub fn announce_error(message: String) -> fn(e) -> Nil {
  fn(error) { io.println(message <> ": " <> ins(error)) }
}

pub fn nillify_error(message: String) -> fn(e) -> Result(a, Nil) {
  fn(error) { Error(io.println(message <> ": " <> ins(error))) }
}

pub fn get_root(vxmls: List(VXML)) -> Result(VXML, String) {
  case vxmls {
    [root] -> Ok(root)
    _ -> Error("found " <> ins(list.length(vxmls)) <> " != 1 top-level nodes")
  }
}

pub fn get_duplicate(list: List(a)) -> Option(a) {
  case list {
    [] -> None
    [first, ..rest] ->
      case list.contains(rest, first) {
        True -> Some(first)
        False -> get_duplicate(rest)
      }
  }
}

pub fn is_tag(vxml: VXML, tag: String) -> Bool {
  case vxml {
    T(_, _) -> False
    V(_, t, _, _) -> t == tag
  }
}

pub fn contains_tag(vxmls: List(VXML), tag: String) -> Bool {
  vxmls |> list.any(is_tag(_, tag))
}

pub fn contains_one_of_tags(vxmls: List(VXML), tags: List(String)) -> Bool {
  tags |> list.any(contains_tag(vxmls, _))
}

//**************************************************************
//* dictionary-building functions
//**************************************************************

pub fn aggregate_on_first(l: List(#(a, b))) -> Dict(a, List(b)) {
  list.fold(
    l,
    dict.from_list([]),
    fn(d, pair) {
      let #(a, b) = pair
      case dict.get(d, a) {
        Error(Nil) -> dict.insert(d, a, [b])
        Ok(prev_list) -> dict.insert(d, a, [b, ..prev_list])
      }
    }
  )
}

pub fn quadruples_to_pairs_pairs(
  l: List(#(a, b, c, d))
) -> List(#(#(a, b), #(c, d))) {
  l
  |> list.map(
    fn (quad) {
      let #(a, b, c, d) = quad
      #(#(a, b), #(c, d))
    }
  )
}

pub fn triples_to_pairs(
  l: List(#(a, b, c))
) -> List(#(a, #(b, c))) {
  l
  |> list.map(
    fn (triple) {
      let #(a, b, c) = triple
      #(a, #(b, c))
    }
  )
}

pub fn triples_to_dict(
  l: List(#(a, b, c))
) -> Dict(a, #(b, c)) {
  l
  |> triples_to_pairs
  |> dict.from_list
}

pub fn triples_to_aggregated_dict(
  l: List(#(a, b, c))
) -> Dict(a, List(#(b, c))) {
  l
  |> triples_to_pairs
  |> aggregate_on_first
}

//**************************************************************
//* either-or functions
//**************************************************************

pub type EitherOr(a, b) {
  Either(a)
  Or(b)
}

fn regroup_eithers_accumulator(
  already_packaged: List(EitherOr(List(a), b)),
  under_construction: List(a),
  upcoming: List(EitherOr(a, b)),
) -> List(EitherOr(List(a), b)) {
  case upcoming {
    [] ->
      [under_construction |> list.reverse |> Either, ..already_packaged]
      |> list.reverse
    [Either(a), ..rest] ->
      regroup_eithers_accumulator(
        already_packaged,
        [a, ..under_construction],
        rest,
      )
    [Or(b), ..rest] ->
      regroup_eithers_accumulator(
        [
          Or(b),
          under_construction |> list.reverse |> Either,
          ..already_packaged
        ],
        [],
        rest,
      )
  }
}

fn regroup_ors_accumulator(
  already_packaged: List(EitherOr(a, List(b))),
  under_construction: List(b),
  upcoming: List(EitherOr(a, b)),
) -> List(EitherOr(a, List(b))) {
  case upcoming {
    [] ->
      [under_construction |> list.reverse |> Or, ..already_packaged]
      |> list.reverse
    [Or(b), ..rest] ->
      regroup_ors_accumulator(already_packaged, [b, ..under_construction], rest)
    [Either(a), ..rest] ->
      regroup_ors_accumulator(
        [
          Either(a),
          under_construction |> list.reverse |> Or,
          ..already_packaged
        ],
        [],
        rest,
      )
  }
}

pub fn remove_ors_unwrap_eithers(ze_list: List(EitherOr(a, b))) -> List(a) {
  list.filter_map(ze_list, fn(either_or) {
    case either_or {
      Either(sth) -> Ok(sth)
      Or(_) -> Error(Nil)
    }
  })
}

pub fn remove_eithers_unwrap_ors(ze_list: List(EitherOr(a, b))) -> List(b) {
  list.filter_map(ze_list, fn(either_or) {
    case either_or {
      Either(_) -> Error(Nil)
      Or(sth) -> Ok(sth)
    }
  })
}

pub fn regroup_eithers(
  ze_list: List(EitherOr(a, b)),
) -> List(EitherOr(List(a), b)) {
  regroup_eithers_accumulator([], [], ze_list)
}

pub fn regroup_ors(ze_list: List(EitherOr(a, b))) -> List(EitherOr(a, List(b))) {
  regroup_ors_accumulator([], [], ze_list)
}

pub fn regroup_eithers_no_empty_lists(
  ze_list: List(EitherOr(a, b)),
) -> List(EitherOr(List(a), b)) {
  regroup_eithers(ze_list)
  |> list.filter(fn(thing) {
    case thing {
      Either(a_list) -> !{ list.is_empty(a_list) }
      Or(_) -> True
    }
  })
}

pub fn regroup_ors_no_empty_lists(
  ze_list: List(EitherOr(a, b)),
) -> List(EitherOr(a, List(b))) {
  regroup_ors(ze_list)
  |> list.filter(fn(thing) {
    case thing {
      Either(_) -> True
      Or(a_list) -> !{ list.is_empty(a_list) }
    }
  })
}

pub fn on_either_on_or(
  t: EitherOr(a, b),
  fn1: fn(a) -> c,
  fn2: fn(b) -> c,
) -> c {
  case t {
    Either(a) -> fn1(a)
    Or(b) -> fn2(b)
  }
}

pub fn map_ors(
  ze_list: List(EitherOr(a, b)),
  f: fn(b) -> c,
) -> List(EitherOr(a, c)) {
  ze_list
  |> list.map(
    fn(thing) {
      case thing {
        Either(load) -> Either(load)
        Or(b) -> Or(f(b))
      }
    }
  )
}

pub fn map_either_ors(
  ze_list: List(EitherOr(a, b)),
  fn1: fn(a) -> c,
  fn2: fn(b) -> c,
) -> List(c) {
  ze_list
  |> list.map(on_either_on_or(_, fn1, fn2))
}

pub fn either_or_misceginator(
  list: List(a),
  condition: fn(a) -> Bool,
) -> List(EitherOr(a, a)) {
  list.map(list, fn(thing) {
    case condition(thing) {
      True -> Either(thing)
      False -> Or(thing)
    }
  })
}

//**************************************************************
//* RegexWithIndexedGroup
//**************************************************************

pub type RegexWithIndexedGroup =
  #(Regexp, Int, Int, String)

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
  list.map_fold(over: splits, from: 0, with: fn(index: Int, split) -> #(
    Int,
    EitherOr(String, Nil),
  ) {
    case index % { num_groups + 1 } == dropped_group + 1 {
      False -> #(index + 1, Either(split))
      True -> #(index + 1, Or(Nil))
    }
  })
  |> pair.second
  |> regroup_eithers
  |> remove_ors_unwrap_eithers
  |> list.map(string.join(_, ""))
}

fn line_split_into_list_either_content_or_blame_indexed_group_version(
  line: BlamedContent,
  re: RegexWithIndexedGroup,
) -> List(EitherOr(BlamedContent, Blame)) {
  let BlamedContent(blame, content) = line
  split_string_by_regex_with_indexed_group(content, re)
  |> list.map(fn(thing) { Either(BlamedContent(blame, thing)) })
  |> list.intersperse(Or(blame))
}

fn line_split_into_list_either_content_or_blame(
  line: BlamedContent,
  re: Regexp,
) -> List(EitherOr(BlamedContent, Blame)) {
  let BlamedContent(blame, content) = line
  regexp.split(with: re, content: content)
  |> list.map(fn(thing) { Either(BlamedContent(blame, thing)) })
  |> list.intersperse(Or(blame))
}

fn replace_regex_by_tag_in_lines_indexed_group_version(
  lines: List(BlamedContent),
  re: RegexWithIndexedGroup,
  tag: String,
) -> List(VXML) {
  lines
  |> list.map(line_split_into_list_either_content_or_blame_indexed_group_version(
    _,
    re,
  ))
  |> list.flatten
  |> regroup_eithers
  |> map_either_ors(
    fn(blamed_contents) {
      let assert [BlamedContent(blame, _), ..] = blamed_contents
      T(blame, blamed_contents)
    },
    fn(blame) { V(blame, tag, [], []) },
  )
}

fn replace_regex_by_tag_in_node_indexed_group_version(
  node: VXML,
  re: RegexWithIndexedGroup,
  tag: String,
) -> List(VXML) {
  case node {
    V(_, _, _, _) -> [node]
    T(_, lines) -> {
      replace_regex_by_tag_in_lines_indexed_group_version(lines, re, tag)
    }
  }
}

fn replace_regex_by_tag_in_nodes_indexed_group_version(
  nodes: List(VXML),
  re: RegexWithIndexedGroup,
  tag: String,
) -> List(VXML) {
  nodes
  |> list.map(replace_regex_by_tag_in_node_indexed_group_version(_, re, tag))
  |> list.flatten
}

fn replace_regexes_by_tags_in_nodes_indexed_group_version(
  nodes: List(VXML),
  rules: List(#(RegexWithIndexedGroup, String)),
) -> List(VXML) {
  case rules {
    [] -> nodes
    [#(regex, tag), ..rest] ->
      replace_regex_by_tag_in_nodes_indexed_group_version(nodes, regex, tag)
      |> replace_regexes_by_tags_in_nodes_indexed_group_version(rest)
  }
}

pub fn replace_regex_by_tag_param_transform_indexed_group_version(
  node: VXML,
  re: RegexWithIndexedGroup,
  tag: String,
) -> Result(List(VXML), DesugaringError) {
  Ok(replace_regex_by_tag_in_node_indexed_group_version(node, re, tag))
}

pub fn replace_regexes_by_tags_param_transform_indexed_group_version(
  node: VXML,
  rules: List(#(RegexWithIndexedGroup, String)),
) -> Result(List(VXML), DesugaringError) {
  Ok(replace_regexes_by_tags_in_nodes_indexed_group_version([node], rules))
}

fn find_replace_in_blamed_content(
  blamed_content: BlamedContent,
  list_pairs: List(#(String, String))
) -> BlamedContent {
  use #(first_from, first_to), rest <- on_empty_on_nonempty(list_pairs, blamed_content)
  BlamedContent(
    blamed_content.blame,
    string.replace(blamed_content.content, first_from, first_to)
  )
  |> find_replace_in_blamed_content(rest)
}

pub fn find_replace_in_t(
  node: VXML,
  list_pairs: List(#(String, String)),
) {
  let assert T(blame, blamed_contents) = node
  T(
    blame,
    blamed_contents |> list.map(find_replace_in_blamed_content(_, list_pairs))
  )

}

pub fn find_replace_in_node(
  node: VXML,
  list_pairs: List(#(String, String))
) -> VXML {
  case node {
    T(_, _) -> find_replace_in_t(node, list_pairs)
    _ -> node
  }
}

pub fn find_replace_in_node_transform_version(
  node: VXML,
  list_pairs: List(#(String, String))
) -> Result(List(VXML), DesugaringError) {
  [find_replace_in_node(node, list_pairs)] |> Ok
}

//**************************************************************
//* regex splitting
//**************************************************************

fn replace_regex_by_tag_in_lines(
  lines: List(BlamedContent),
  re: Regexp,
  tag: String,
) -> List(VXML) {
  lines
  |> list.map(line_split_into_list_either_content_or_blame(_, re))
  |> list.flatten
  |> regroup_eithers
  |> map_either_ors(
    fn(blamed_contents) {
      let assert [BlamedContent(blame, _), ..] = blamed_contents
      T(blame, blamed_contents)
    },
    fn(blame) { V(blame, tag, [], []) },
  )
}

fn replace_regex_by_tag_in_node(
  node: VXML,
  re: Regexp,
  tag: String,
) -> List(VXML) {
  case node {
    V(_, _, _, _) -> [node]
    T(_, lines) -> {
      replace_regex_by_tag_in_lines(lines, re, tag)
    }
  }
}

fn replace_regex_by_tag_in_nodes(
  nodes: List(VXML),
  re: Regexp,
  tag: String,
) -> List(VXML) {
  nodes
  |> list.map(replace_regex_by_tag_in_node(_, re, tag))
  |> list.flatten
}

fn replace_regexes_by_tags_in_nodes(
  nodes: List(VXML),
  rules: List(#(Regexp, String)),
) -> List(VXML) {
  case rules {
    [] -> nodes
    [#(regex, tag), ..rest] ->
      replace_regex_by_tag_in_nodes(nodes, regex, tag)
      |> replace_regexes_by_tags_in_nodes(rest)
  }
}

pub fn replace_regex_by_tag_param_transform(
  node: VXML,
  re: Regexp,
  tag: String,
) -> Result(List(VXML), DesugaringError) {
  Ok(replace_regex_by_tag_in_node(node, re, tag))
}

pub fn replace_regexes_by_tags_param_transform(
  node: VXML,
  rules: List(#(Regexp, String)),
) -> Result(List(VXML), DesugaringError) {
  Ok(replace_regexes_by_tags_in_nodes([node], rules))
}

//**************************************************************
//* delimiter_pattern splitting
//**************************************************************

// fn line_split_into_list_either_content_or_blame_delimiter_pattern_version(
//   line: BlamedContent,
//   pattern: DelimiterPattern,
// ) -> List(EitherOr(BlamedContent, Blame)) {
//   let BlamedContent(blame, content) = line
//   delimiter_pattern_string_split(content, pattern)
//   |> list.map(fn(thing) { Either(BlamedContent(blame, thing)) })
//   |> list.intersperse(Or(blame))
// }

// fn replace_delimiter_pattern_by_tag_in_lines(
//   lines: List(BlamedContent),
//   pattern: DelimiterPattern,
//   tag: String,
// ) -> List(VXML) {
//   lines
//   |> list.map(
//     line_split_into_list_either_content_or_blame_delimiter_pattern_version(
//       _,
//       pattern,
//     ),
//   )
//   |> list.flatten
//   |> regroup_eithers
//   |> map_either_ors(
//     fn(blamed_contents) {
//       let assert [BlamedContent(blame, _), ..] = blamed_contents
//       T(blame, blamed_contents)
//     },
//     fn(blame) { V(blame, tag, [], []) },
//   )
// }

// fn replace_delimiter_pattern_by_tag_in_node(
//   node: VXML,
//   pattern: DelimiterPattern,
//   tag: String,
// ) -> List(VXML) {
//   case node {
//     V(_, _, _, _) -> [node]
//     T(_, lines) -> {
//       replace_delimiter_pattern_by_tag_in_lines(lines, pattern, tag)
//     }
//   }
// }

// fn replace_delimiter_pattern_by_tag_in_nodes(
//   nodes: List(VXML),
//   pattern: DelimiterPattern,
//   tag: String,
// ) -> List(VXML) {
//   nodes
//   |> list.map(replace_delimiter_pattern_by_tag_in_node(_, pattern, tag))
//   |> list.flatten
// }

// fn replace_delimiter_patterns_by_tags_in_nodes(
//   nodes: List(VXML),
//   rules: List(#(DelimiterPattern, String)),
// ) -> List(VXML) {
//   case rules {
//     [] -> nodes
//     [#(pattern, tag), ..rest] ->
//       replace_delimiter_pattern_by_tag_in_nodes(nodes, pattern, tag)
//       |> replace_delimiter_patterns_by_tags_in_nodes(rest)
//   }
// }

// pub fn replace_delimiter_pattern_by_tag_param_transform(
//   node: VXML,
//   pattern: DelimiterPattern,
//   tag: String,
// ) -> Result(List(VXML), DesugaringError) {
//   Ok(replace_delimiter_pattern_by_tag_in_node(node, pattern, tag))
// }

// pub fn replace_delimiter_patterns_by_tags_param_transform(
//   node: VXML,
//   rules: List(#(DelimiterPattern, String)),
// ) -> Result(List(VXML), DesugaringError) {
//   Ok(replace_delimiter_patterns_by_tags_in_nodes([node], rules))
// }

//**************************************************************
//* blame etracting function                                   *
//**************************************************************

pub fn get_blame(vxml: VXML) -> Blame {
  case vxml {
    T(blame, _) -> blame
    V(blame, _, _, _) -> blame
  }
}

pub const no_blame = Blame("", -1, [])

pub fn assert_get_first_blame(vxmls: List(VXML)) -> Blame {
  let assert [first, ..] = vxmls
  get_blame(first)
}

pub fn append_blame_comment(blame: Blame, comment: String) -> Blame {
  let Blame(filename, indent, comments) = blame
  Blame(filename, indent, [comment, ..comments])
}

//**************************************************************
//* misc (children collecting, inserting, ...)
//**************************************************************

pub fn remove_lines_while_empty(
  l: List(BlamedContent)
) -> List(BlamedContent) {
  case l {
    [] -> []
    [first, ..rest] -> case first.content {
      "" -> remove_lines_while_empty(rest)
      _ -> l
    }
  }
}

pub fn t_remove_starting_empty_lines(
  vxml: VXML
) -> Option(VXML) {
  let assert T(blame, lines) = vxml
  let lines = remove_lines_while_empty(lines)
  case lines {
    [] -> None
    _ -> Some(T(blame, lines))
  }
}

pub fn t_remove_ending_empty_lines(
  vxml: VXML
) -> Option(VXML) {
  let assert T(blame, lines) = vxml
  let lines = remove_lines_while_empty(lines |> list.reverse) |> list.reverse
  case lines {
    [] -> None
    _ -> Some(T(blame, lines))
  }
}

pub fn v_remove_starting_empty_lines(
  vxml: VXML
) -> VXML {
  let assert V(blame, tag, attrs, children) = vxml
  let children = case children {
    [T(_, _) as first, ..rest] -> {
      case t_remove_starting_empty_lines(first) {
        Some(guy) -> [guy, ..rest]
        None -> rest
      }
    }
    _ -> children
  }
  V(blame, tag, attrs, children)
}

pub fn v_remove_ending_empty_lines(
  vxml: VXML
) -> VXML {
  let assert V(blame, tag, attrs, children) = vxml
  let children = case children |> list.reverse {
    [T(_, _) as first, ..rest] -> {
      case t_remove_ending_empty_lines(first) {
        Some(guy) -> [guy, ..rest] |> list.reverse
        None -> rest |> list.reverse
      }
    }
    _ -> children
  }
  V(blame, tag, attrs, children)
}

pub fn v_remove_starting_and_ending_empty_lines(
  vxml: VXML
) -> VXML {
  vxml
  |> v_remove_starting_empty_lines
  |> v_remove_ending_empty_lines
}

pub fn extract_starting_spaces_from_text(
  content: String
) -> #(String, String) {
  let new_content = string.trim_start(content)
  let num_spaces = string.length(content) - string.length(new_content)
  #(string.repeat(" ", num_spaces), new_content)
}

pub fn extract_ending_spaces_from_text(
  content: String
) -> #(String, String) {
  let new_content = string.trim_end(content)
  let num_spaces = string.length(content) - string.length(new_content)
  #(string.repeat(" ", num_spaces), new_content)
}

pub fn t_extract_starting_spaces(
  node: VXML
) -> #(Option(VXML), VXML) {
  let assert T(blame, blamed_contents) = node
  let assert [first, ..rest] = blamed_contents
  case extract_starting_spaces_from_text(first.content) {
    #("", _) -> #(None, node)
    #(spaces, not_spaces) -> #(
      Some(T(first.blame, [BlamedContent(first.blame, spaces)])),
      T(blame, [BlamedContent(first.blame, not_spaces), ..rest])
    )
  }
}

pub fn t_extract_ending_spaces(
  node: VXML
) -> #(Option(VXML), VXML) {
  let assert T(blame, blamed_contents) = node
  let assert [first, ..rest] = blamed_contents |> list.reverse
  case extract_ending_spaces_from_text(first.content) {
    #("", _) -> #(None, node)
    #(spaces, not_spaces) -> #(
      Some(T(first.blame, [BlamedContent(first.blame, spaces)])),
      T(blame, [BlamedContent(first.blame, not_spaces), ..rest] |> list.reverse)
    )
  }
}

pub fn v_extract_starting_spaces(
  node: VXML
) -> #(Option(VXML), VXML) {
  let assert V(blame, tag, attrs, children) = node
  case children {
    [T(_, _) as first, ..rest] -> {
      case t_extract_starting_spaces(first) {
        #(None, _) -> #(None, node)
        #(Some(guy), first) -> #(Some(guy), V(blame, tag, attrs, [first, ..rest]))
      }
    }
    _ -> #(None, node)
  }
}

pub fn v_extract_ending_spaces(
  node: VXML
) -> #(Option(VXML), VXML) {
  let assert V(blame, tag, attrs, children) = node
  case children |> list.reverse {
    [T(_, _) as first, ..rest] -> {
      case t_extract_ending_spaces(first) {
        #(None, _) -> #(None, node)
        #(Some(guy), first) -> #(Some(guy), V(blame, tag, attrs, [first, ..rest] |> list.reverse))
      }
    }
    _ -> #(None, node)
  }
}

pub fn encode_starting_spaces_in_string(
  content: String
) -> String {
  let new_content = string.trim_start(content)
  let num_spaces = string.length(content) - string.length(new_content)
  string.repeat("&ensp;", num_spaces) <> new_content
}

pub fn encode_ending_spaces_in_string(
  content: String
) -> String {
  let new_content = string.trim_end(content)
  let num_spaces = string.length(content) - string.length(new_content)
  new_content <> string.repeat("&ensp;", num_spaces)
}

pub fn encode_starting_spaces_in_blamed_content(
  blamed_content: BlamedContent
) -> BlamedContent {
  BlamedContent(
    blamed_content.blame,
    blamed_content.content |> encode_starting_spaces_in_string
  )
}

pub fn encode_ending_spaces_in_blamed_content(
  blamed_content: BlamedContent
) -> BlamedContent {
  BlamedContent(
    blamed_content.blame,
    blamed_content.content |> encode_ending_spaces_in_string
  )
}

pub fn encode_starting_spaces_if_text(
  vxml: VXML,
) -> VXML {
  case vxml {
    V(_, _, _, _) -> vxml
    T(blame, blamed_contents) -> {
      let assert [first, ..rest] = blamed_contents
      T(
        blame,
        [
          first |> encode_starting_spaces_in_blamed_content,
          ..rest
        ]
      )
    }
  }
}

pub fn encode_ending_spaces_if_text(
  vxml: VXML,
) -> VXML {
  case vxml {
    V(_, _, _, _) -> vxml
    T(blame, blamed_contents) -> {
      let assert [last, ..rest] = {blamed_contents |> list.reverse }
      T(
        blame,
        [
          last |> encode_ending_spaces_in_blamed_content,
          ..rest
        ] |> list.reverse
      )
    }
  }
}

pub fn encode_starting_spaces_in_first_node(
  vxmls: List(VXML)
) -> List(VXML) {
  case vxmls {
    [] -> []
    [first, ..rest] -> [
      first |> encode_starting_spaces_if_text,
      ..rest
    ]
  }
}

pub fn encode_ending_spaces_in_last_node(
  vxmls: List(VXML)
) -> List(VXML) {
  case vxmls |> list.reverse {
    [] -> []
    [last, ..rest] -> [
      last |> encode_ending_spaces_if_text,
      ..rest
    ] |> list.reverse
  }
}

pub fn t_start_insert_text(node: VXML, text: String) {
  let assert T(blame, lines) = node
  let assert [BlamedContent(blame_first, content_first), ..other_lines] = lines
  T(blame, [BlamedContent(blame_first, text <> content_first), ..other_lines])
}

pub fn t_end_insert_text(node: VXML, text: String) {
  let assert T(blame, lines) = node
  let assert [BlamedContent(blame_last, content_last), ..other_lines] =
    lines |> list.reverse
  T(
    blame,
    [BlamedContent(blame_last, content_last <> text), ..other_lines]
      |> list.reverse,
  )
}

pub fn list_start_insert_text(
  blame: Blame,
  vxmls: List(VXML),
  text: String,
) -> List(VXML) {
  case vxmls {
    [T(_, _) as first, ..rest] -> [
      t_start_insert_text(first, text),
      ..rest
    ]
    _ -> [
      T(blame, [BlamedContent(blame, text)]),
      ..vxmls
    ]
  }
}

pub fn list_end_insert_text(
  blame: Blame,
  vxmls: List(VXML),
  text: String,
) -> List(VXML) {
  case vxmls |> list.reverse {
    [T(_, _) as first, ..rest] -> [
      t_end_insert_text(first, text),
      ..rest
    ] |> list.reverse
    _ -> [
      T(blame, [BlamedContent(blame, text)]),
      ..vxmls
    ] |> list.reverse
  }
}

pub fn v_start_insert_text(
  node: VXML,
  text: String,
) -> VXML {
  let assert V(blame, tag, attrs, children) = node {
    let children = list_start_insert_text(blame, children, text)
    V(blame, tag, attrs, children)
  }
}

pub fn v_end_insert_text(
  node: VXML,
  text: String,
) -> VXML {
  let assert V(blame, tag, attrs, children) = node {
    let children = list_end_insert_text(blame, children, text)
    V(blame, tag, attrs, children)
  }
}

// "word" == "non-whitespace" == empty string if string ends with
// whitespace
//
// returns:                -> #(everything_before, after_last_space)
fn break_out_last_word(input: String) -> #(String, String) {
  case input |> string.reverse |> string.split_once(" ") {
    Ok(#(yoro, rest)) -> #(
      {" " <> rest} |> string.reverse,
      yoro |> string.reverse,
    )
    _ -> #(
      "",
      input
    )
  }
}

// "word" == "non-whitespace" == empty string if string startss with
// whitespace
//
// returns:                -> #(before_first_space, everything_afterwards)
fn break_out_first_word(input: String) -> #(String, String) {
  case input |> string.split_once(" ") {
    Ok(#(yoro, rest)) -> #(yoro, " " <> rest)
    _ -> #(input, "")
  }
}

// "word" == "non-whitespace" == empty string if node ends with
// whitespace
//
// returns                                           #(node leftover with last word taken out, Option(new T(_, _) containing last word))
pub fn extract_last_word_from_t_node_if_t(vxml: VXML) -> #(VXML, Option(VXML)) {
  case vxml {
    V(_, _, _, _) -> #(vxml, None)
    T(blame, contents) -> {
      let reversed = contents |> list.reverse
      let assert [last, ..rest] = reversed
      case break_out_last_word(last.content) {
        #(_, "") -> #(vxml, None)
        #(before_last_word, last_word) -> {
          let contents = [BlamedContent(last.blame, before_last_word), ..rest] |> list.reverse
          #(
            T(blame, contents),
            Some(T(last.blame, [BlamedContent(last.blame, last_word)]))
          )
        }
      }
    }
  }
}

// "word" == "non-whitespace" == empty string if node starts with
// whitespace
//
// returns                                            #(Option(new T(_, _) containing first word), node leftover with word taken out)
pub fn extract_first_word_from_t_node_if_t(vxml: VXML) -> #(Option(VXML), VXML) {
  case vxml {
    V(_, _, _, _) -> #(None, vxml)
    T(blame, contents) -> {
      let assert [first, ..rest] = contents
      case break_out_first_word(first.content) {
        #("", _) -> #(None, vxml)
        #(first_word, after_first_word) -> {
          let contents = [BlamedContent(first.blame, after_first_word), ..rest]
          #(
            Some(T(first.blame, [BlamedContent(first.blame, first_word)])),
            T(blame, contents)
          )
        }
      }
    }
  }
}

pub fn drop_ending_slash(path: String) -> String {
  case string.ends_with(path, "/") {
    True -> string.drop_end(path, 1)
    False -> path
  }
}

pub fn drop_starting_slash(path: String) -> String {
  case string.starts_with(path, "/") {
    True -> string.drop_start(path, 1)
    False -> path
  }
}

pub fn prepend_attribute(vxml: VXML, attr: BlamedAttribute) {
  let assert V(blame, tag, attrs, children) = vxml
  V(
    blame,
    tag,
    [attr, ..attrs],
    children
  )
}

pub fn prepend_unique_key_attribute(vxml: VXML, attr: BlamedAttribute) -> Result(VXML, Nil) {
  case get_attribute_by_name(vxml, attr.key) {
    Some(_) -> Error(Nil)
    None -> Ok(prepend_attribute(vxml, attr))
  }
}

pub fn prepend_child(vxml: VXML, child: VXML) {
  let assert V(blame, tag, attributes, children) = vxml
  V(
    blame,
    tag, 
    attributes,
    [child, ..children]
  )
}

pub fn get_attribute_keys(attrs: List(BlamedAttribute)) -> List(String) {
  attrs
  |> list.map(fn(attr) { attr.key })
}

pub fn get_attribute_by_name(vxml: VXML, name: String) -> Option(BlamedAttribute) {
  let assert V(_, _, blamed_attributes, _) = vxml
  case list.find(
    blamed_attributes,
    fn (blamed_attribute) { blamed_attribute.key == name }
  ) {
    Error(Nil) -> None
    Ok(thing) -> Some(thing)
  }
}

pub fn has_attribute(vxml: VXML, name: String, value: String) -> Bool {
  let assert V(_, _, blamed_attributes, _) = vxml
  case list.find(
    blamed_attributes,
    fn (blamed_attribute) { blamed_attribute.key == name && blamed_attribute.value == value }
  ) {
    Error(Nil) -> False
    Ok(_) -> True
  }
}

pub fn get_children(vxml: VXML) -> List(VXML) {
  let assert V(_, _, _, children) = vxml
  children
}

pub fn tag_equals(vxml: VXML, tag: String) -> Bool {
  let assert V(_, v_tag, _, _) = vxml
  v_tag == tag
}

pub fn is_v_and_tag_equals(vxml: VXML, tag: String) -> Bool {
  case vxml {
    T(_, _) -> False
    _ -> tag_equals(vxml, tag)
  }
}

pub fn is_v_and_has_attr(vxml: VXML, key: String, value: String) -> Bool {
  case vxml {
    T(_, _) -> False
    _ -> {
      has_attribute(vxml, key, value)
    }
  }
}

pub fn get_tag(vxml: VXML) -> String {
  let assert V(_, tag, _, _) = vxml
  tag
}

pub fn filter_children(vxml: VXML, condition: fn(VXML) -> Bool) -> List(VXML) {
  let assert V(_, _, _, children) = vxml
  list.filter(children, condition)
}

pub fn children_with_tag(vxml: VXML, tag: String) -> List(VXML) {
  filter_children(vxml, is_v_and_tag_equals(_, tag))
}

pub fn descendants_with_tag(vxml: VXML, tag: String) -> List(VXML) {
  case vxml {
    T(_, _) -> []
    V(_, _, _, children) -> {
      let children_with_tag = children_with_tag(vxml, tag)

       list.flatten([
        children_with_tag,
        list.map(children, descendants_with_tag(_, tag)) |> list.flatten
      ])
    }
  }
}

pub fn children_with_attr(vxml: VXML, key: String, value: String) -> List(VXML) {
  filter_children(vxml, is_v_and_has_attr(_, key, value))
}

pub type SingletonError {
  MoreThanOne
  LessThanOne
}

pub fn read_singleton(z: List(a)) -> Result(a, SingletonError) {
  case z {
    [] -> Error(LessThanOne)
    [one] -> Ok(one)
    _ -> Error(MoreThanOne)
  }
}

pub fn unique_child_with_tag(vxml: VXML, tag: String) -> Result(VXML, SingletonError) {
  children_with_tag(vxml, tag)
  |> read_singleton
}

pub fn digest(vxml: VXML) -> String {
  case vxml {
    V(_, tag, _, _) -> "V(_, " <> tag <> ", _, _)"
    T(_, _) -> "T(_, _)"
  }
}

//**************************************************************
//* desugaring efforts #1 deliverable: 'pub' function(s) below *
//**************************************************************

pub type NodeToNodeTransform =
  fn(VXML) -> Result(VXML, DesugaringError)

fn node_to_node_desugar_many(
  vxmls: List(VXML),
  transform: NodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  vxmls
  |> list.map(node_to_node_desugar_one(_, transform))
  |> result.all
}

fn node_to_node_desugar_one(
  node: VXML,
  transform: NodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> transform(node)
    V(blame, tag, attrs, children) -> {
      case node_to_node_desugar_many(children, transform) {
        Ok(transformed_children) ->
          transform(V(blame, tag, attrs, transformed_children))
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn node_to_node_desugarer_factory(
  transform: NodeToNodeTransform,
) -> Desugarer {
  node_to_node_desugar_one(_, transform)
}

//**********************************************************************
//* desugaring efforts #1.5: depth-first-search, node-to-node          *
//* transform with lots of side info (not only ancestors)              *
//**********************************************************************

pub type NodeToNodeFancyTransform =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(VXML, DesugaringError)

fn fancy_depth_first_node_to_node_children_traversal(
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodeFancyTransform,
) -> Result(#(List(VXML), List(VXML), List(VXML)), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, []),
      )
    [first, ..rest] -> {
      use first_replacement <- result.then(
        fancy_depth_first_node_to_node_desugar_one(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      fancy_depth_first_node_to_node_children_traversal(
        ancestors,
        [first, ..previous_siblings_before_mapping],
        [first_replacement, ..previous_siblings_after_mapping],
        rest,
        transform,
      )
    }
  }
}

fn fancy_depth_first_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodeFancyTransform,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) ->
      transform(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    V(blame, tag, attrs, children) -> {
      case
        fancy_depth_first_node_to_node_children_traversal(
          [node, ..ancestors],
          [],
          [],
          children,
          transform,
        )
      {
        Ok(#(_, mapped_children, _)) ->
          transform(
            V(blame, tag, attrs, mapped_children |> list.reverse),
            ancestors,
            previous_siblings_before_mapping,
            previous_siblings_after_mapping,
            following_siblings_before_mapping,
          )
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn node_to_node_fancy_desugarer_factory(
  transform: NodeToNodeFancyTransform,
) -> Desugarer {
  fancy_depth_first_node_to_node_desugar_one(_, [], [], [], [], transform)
}

//**********************************************************************
//* desugaring efforts #1.6: depth-first-search, node-to-nodes         *
//* transform with lots of side info (not only ancestors)              *
//**********************************************************************

pub type NodeToNodesFancyTransform =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(List(VXML), DesugaringError)

fn fancy_depth_first_node_to_nodes_children_traversal(
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodesFancyTransform,
) -> Result(#(List(VXML), List(VXML), List(VXML)), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, []),
      )
    [first, ..rest] -> {
      use first_replacement <- result.then(
        fancy_depth_first_node_to_nodes_desugar_one(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      fancy_depth_first_node_to_nodes_children_traversal(
        ancestors,
        [first, ..previous_siblings_before_mapping],
        list.flatten([
          first_replacement |> list.reverse,
          previous_siblings_after_mapping,
        ]),
        rest,
        transform,
      )
    }
  }
}

fn fancy_depth_first_node_to_nodes_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodesFancyTransform,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) ->
      transform(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    V(blame, tag, attrs, children) -> {
      case
        fancy_depth_first_node_to_nodes_children_traversal(
          [node, ..ancestors],
          [],
          [],
          children,
          transform,
        )
      {
        Ok(#(_, mapped_children, _)) ->
          transform(
            V(blame, tag, attrs, mapped_children |> list.reverse),
            ancestors,
            previous_siblings_before_mapping,
            previous_siblings_after_mapping,
            following_siblings_before_mapping,
          )
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn node_to_nodes_fancy_desugarer_factory(
  transform: NodeToNodesFancyTransform,
) -> Desugarer {
  fn(root: VXML) {
    use vxmls <- result.then(fancy_depth_first_node_to_nodes_desugar_one(
      root,
      [],
      [],
      [],
      [],
      transform,
    ))

    case get_root(vxmls) {
      Ok(r) -> Ok(r)
      Error(message) -> Error(GetRootError(message))
    }
  }
}

//**********************************************************************
//* desugaring efforts #1.7: turn ordinary node-to-node(s) transform   *
//* into parent-avoiding fancy transform                               *
//**********************************************************************

pub fn extract_tag(node: VXML) -> String {
  let assert V(_, tag, _, _) = node
  tag
}

pub fn is_text_node(node: VXML) -> Bool {
  case node {
    T(_, _) -> True
    V(_, _, _, _) -> False
  }
}

pub fn prevent_node_to_node_transform_inside(
  transform: NodeToNodeTransform,
  forbidden_tag: List(String),
) -> NodeToNodeFancyTransform {
  fn(
    node: VXML,
    ancestors: List(VXML),
    _: List(VXML),
    _: List(VXML),
    _: List(VXML),
  ) -> Result(VXML, DesugaringError) {
    let node_is_forbidden_tag = case node {
      T(_, _) -> False
      V(_, tag, _, _) -> list.contains(forbidden_tag, tag)
    }
    case
      node_is_forbidden_tag
      || list.any(ancestors, fn(ancestor) {
        list.contains(forbidden_tag, extract_tag(ancestor))
      })
    {
      False -> transform(node)
      True -> Ok(node)
    }
  }
}

pub fn prevent_node_to_nodes_transform_inside(
  transform: NodeToNodesTransform,
  neutralize_here: List(String),
) -> NodeToNodesFancyTransform {
  fn(
    node: VXML,
    ancestors: List(VXML),
    _: List(VXML),
    _: List(VXML),
    _: List(VXML),
  ) -> Result(List(VXML), DesugaringError) {
    case
      list.any(ancestors, fn(ancestor) {
        list.contains(neutralize_here, extract_tag(ancestor))
      })
    {
      False -> transform(node)
      True -> Ok([node])
    }
  }
}

//**************************************************************
//* desugaring efforts #1.8: stateful node-to-node
//**************************************************************

pub type StatefulNodeToNodeTransform(a) =
  fn(VXML, a) -> Result(#(VXML, a), DesugaringError)

fn stateful_node_to_node_many(
  state: a,
  vxmls: List(VXML),
  transform: StatefulNodeToNodeTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
  case vxmls {
    [] -> Ok(#([], state))
    [first, ..rest] -> {
      use #(first_transformed, new_state) <- result.then(
        stateful_node_to_node_desugar_one(state, first, transform),
      )
      use #(rest_transformed, new_new_state) <- result.then(
        stateful_node_to_node_many(new_state, rest, transform),
      )
      Ok(#([first_transformed, ..rest_transformed], new_new_state))
    }
  }
}

fn stateful_node_to_node_desugar_one(
  state: a,
  node: VXML,
  transform: StatefulNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> transform(node, state)
    V(blame, tag, attrs, children) -> {
      use #(transformed_children, new_state) <- result.then(
        stateful_node_to_node_many(state, children, transform),
      )
      transform(V(blame, tag, attrs, transformed_children), new_state)
    }
  }
}

pub fn stateful_node_to_node_desugarer_factory(
  transform: StatefulNodeToNodeTransform(a),
  initial_state: a,
) -> Desugarer {
  fn(vxml) {
    case stateful_node_to_node_desugar_one(initial_state, vxml, transform) {
      Error(err) -> Error(err)
      Ok(#(new_vxml, _)) -> Ok(new_vxml)
    }
  }
}

//**************************************************************
//* desugaring efforts #1.9: stateful node-to-node
//**************************************************************

pub type StatefulDownAndUpNodeToNodeTransform(a) {
  StatefulDownAndUpNodeToNodeTransform(
    before_transforming_children: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
    after_transforming_children: fn(VXML, a, a) ->
      Result(#(VXML, a), DesugaringError),
  )
}

fn stateful_down_up_node_to_node_many(
  state: a,
  vxmls: List(VXML),
  transform: StatefulDownAndUpNodeToNodeTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
  case vxmls {
    [] -> Ok(#([], state))
    [first, ..rest] -> {
      use #(first_transformed, new_state) <- result.then(
        stateful_down_up_node_to_node_one(state, first, transform),
      )
      use #(rest_transformed, new_new_state) <- result.then(
        stateful_down_up_node_to_node_many(new_state, rest, transform),
      )
      Ok(#([first_transformed, ..rest_transformed], new_new_state))
    }
  }
}

fn stateful_down_up_node_to_node_apply_first_half(
  state: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  let StatefulDownAndUpNodeToNodeTransform(
    before_transforming_children: t1,
    after_transforming_children: _,
  ) = transform_pair
  t1(node, state)
}

fn stateful_down_up_node_to_node_apply_second_half(
  original_state_when_node_entered: a,
  new_state_after_children_processed: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  let StatefulDownAndUpNodeToNodeTransform(
    before_transforming_children: _,
    after_transforming_children: t2,
  ) = transform_pair
  t2(node, original_state_when_node_entered, new_state_after_children_processed)
}

fn stateful_down_up_node_to_node_apply_to_children(
  state: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> Ok(#(node, state))
    V(blame, tag, attrs, children) -> {
      use #(new_children, new_state) <- result.then(
        stateful_down_up_node_to_node_many(state, children, transform_pair),
      )
      Ok(#(V(blame, tag, attrs, new_children), new_state))
    }
  }
}

fn stateful_down_up_node_to_node_one(
  state: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  use #(new_node, new_state) <- result.then(
    stateful_down_up_node_to_node_apply_first_half(state, node, transform_pair),
  )
  use #(new_new_node, new_new_state) <- result.then(
    stateful_down_up_node_to_node_apply_to_children(
      new_state,
      new_node,
      transform_pair,
    ),
  )
  stateful_down_up_node_to_node_apply_second_half(
    state,
    new_new_state,
    new_new_node,
    transform_pair,
  )
}

pub fn stateful_down_up_node_to_node_desugarer_factory(
  transform: StatefulDownAndUpNodeToNodeTransform(a),
  initial_state: a,
) -> Desugarer {
  fn(vxml) {
    case stateful_down_up_node_to_node_one(initial_state, vxml, transform) {
      Error(err) -> Error(err)
      Ok(#(new_vxml, _)) -> Ok(new_vxml)
    }
  }
}

pub type StatefulDownAndUpNodeToNodesTransform(a) {
  StatefulDownAndUpNodeToNodesTransform(
    before_transforming_children: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
    after_transforming_children: fn(VXML, a, a) ->
      Result(#(List(VXML), a), DesugaringError),
  )
}

fn stateful_down_up_node_to_nodes_many(
  state: a,
  vxmls: List(VXML),
  transform: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
  case vxmls {
    [] -> Ok(#([], state))
    [first, ..rest] -> {
      use #(first_transformed, new_state) <- result.then(
        stateful_down_up_node_to_nodes_one(state, first, transform),
      )
      use #(rest_transformed, new_new_state) <- result.then(
        stateful_down_up_node_to_nodes_many(new_state, rest, transform),
      )
      Ok(#(list.flatten([first_transformed, rest_transformed]), new_new_state))
    }
  }
}

fn stateful_down_up_node_to_nodes_apply_first_half(
  state: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  let StatefulDownAndUpNodeToNodesTransform(
    before_transforming_children: t1,
    after_transforming_children: _,
  ) = transform_pair
  t1(node, state)
}

fn stateful_down_up_node_to_nodes_apply_second_half(
  original_state_when_node_entered: a,
  new_state_after_children_processed: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
  let StatefulDownAndUpNodeToNodesTransform(
    before_transforming_children: _,
    after_transforming_children: t2,
  ) = transform_pair
  t2(node, original_state_when_node_entered, new_state_after_children_processed)
}

fn stateful_down_up_node_to_nodes_apply_to_children(
  state: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> Ok(#(node, state))
    V(blame, tag, attrs, children) -> {
      use #(new_children, new_state) <- result.then(
        stateful_down_up_node_to_nodes_many(state, children, transform_pair),
      )
      Ok(#(V(blame, tag, attrs, new_children), new_state))
    }
  }
}

fn stateful_down_up_node_to_nodes_one(
  state: a,
  node: VXML,
  transform_pair: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
  use #(new_node, new_state) <- result.then(
    stateful_down_up_node_to_nodes_apply_first_half(state, node, transform_pair),
  )
  use #(new_new_node, new_new_state) <- result.then(
    stateful_down_up_node_to_nodes_apply_to_children(
      new_state,
      new_node,
      transform_pair,
    ),
  )
  stateful_down_up_node_to_nodes_apply_second_half(
    state,
    new_new_state,
    new_new_node,
    transform_pair,
  )
}

pub fn stateful_down_up_node_to_nodes_desugarer_factory(
  transform: StatefulDownAndUpNodeToNodesTransform(a),
  initial_state: a,
) -> Desugarer {
  fn(vxml) {
    case stateful_down_up_node_to_nodes_one(initial_state, vxml, transform) {
      Error(err) -> Error(err)
      Ok(#(new_vxml, _)) -> {
        let assert [new_vxml] = new_vxml
        Ok(new_vxml)
      }
    }
  }
}

//**********************************************************************
//* desugaring efforts #2: depth-first-search, node-to-nodes transform *
//* ; see 'pub' function(s) below                                      *
//**********************************************************************

pub type NodeToNodesTransform =
  fn(VXML) -> Result(List(VXML), DesugaringError)

fn depth_first_node_to_nodes_desugar_many(
  vxmls: List(VXML),
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  vxmls
  |> list.map(depth_first_node_to_nodes_desugar_one(_, transform))
  |> result.all
  |> result.map(list.flatten(_))
}

fn depth_first_node_to_nodes_desugar_one(
  node: VXML,
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> transform(node)
    V(blame, tag, attrs, children) -> {
      case depth_first_node_to_nodes_desugar_many(children, transform) {
        Ok(new_children) -> transform(V(blame, tag, attrs, new_children))
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn node_to_nodes_desugarer_factory(
  transform: NodeToNodesTransform,
) -> Desugarer {
  fn(root: VXML) {
    use vxmls <- result.then(depth_first_node_to_nodes_desugar_one(
      root,
      transform,
    ))

    case get_root(vxmls) {
      Ok(r) -> Ok(r)
      Error(message) -> Error(GetRootError(message))
    }
  }
}

//**************************************************************
//* desugaring efforts #3: breadth-first-search, node-to-node2 *
//* ; see 'pub' function below                                 *
//**************************************************************

pub type EarlyReturn(a) {
  GoBack(a)
  Continue(a)
  Err(DesugaringError)
}

pub type EarlyReturnNodeToNodeTransform =
  fn(VXML, List(VXML)) -> EarlyReturn(VXML)

fn early_return_node_to_node_desugar_many(
  vxmls: List(VXML),
  ancestors: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  vxmls
  |> list.map(early_return_node_to_node_desugar_one(_, ancestors, transform))
  |> result.all
}

fn early_return_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  case transform(node, ancestors) {
    GoBack(new_node) -> Ok(new_node)
    Continue(new_node) -> {
      case new_node {
        T(_, _) -> Ok(new_node)
        V(blame, tag, attrs, children) -> {
          case
            early_return_node_to_node_desugar_many(
              children,
              [new_node, ..ancestors],
              transform,
            )
          {
            Ok(new_children) -> Ok(V(blame, tag, attrs, new_children))
            Error(err) -> Error(err)
          }
        }
      }
    }
    Err(error) -> Error(error)
  }
}

pub fn early_return_node_to_node_desugarer_factory(
  transform: EarlyReturnNodeToNodeTransform,
) -> Desugarer {
  early_return_node_to_node_desugar_one(_, [], transform)
}

//*********
//* types *
//*********

pub type DesugaringError {
  DesugaringError(blame: Blame, message: String)
  GetRootError(message: String)
}

pub type Desugarer =
  fn(VXML) -> Result(VXML, DesugaringError)

pub type DesugarerDescription {
  DesugarerDescription(
    function_name: String,
    extra: Option(String),
    general_description: String,
  )
}

pub type Pipe {
  Pipe(
    description: DesugarerDescription,
    desugarer: Desugarer,
  )
}
