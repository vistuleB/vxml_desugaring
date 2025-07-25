import gleam/float
import gleam/int
import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/pair
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string.{inspect as ins}
import gleam/regexp
import vxml.{type BlamedAttribute, BlamedAttribute, type BlamedContent, type VXML, BlamedContent, T, V,
vxml_to_string}

pub const no_list = True

pub type LatexDelimiterSingleton {
  DoubleDollarSingleton
  SingleDollarSingleton
  BackslashOpeningParenthesis
  BackslashClosingParenthesis
  BackslashOpeningSquareBracket
  BackslashClosingSquareBracket
}

pub type LatexDelimiterPair {
  DoubleDollar
  SingleDollar
  BackslashParenthesis
  BackslashSquareBracket
}

pub type CSSUnit {
  PX
  REM
  EM
}

fn css_unit_from_string(s: String) -> Option(CSSUnit) {
  case s {
    "px" -> Some(PX)
    "rem" -> Some(REM)
    "em" -> Some(EM)
    _ -> None
  }
}

pub fn parse_to_float(s: String) -> Result(Float, Nil) {
  case float.parse(s), int.parse(s) {
    Ok(number), _ -> Ok(number)
    _, Ok(number) -> Ok(int.to_float(number))
    _, _ -> Error(Nil)
  }
}

pub fn parse_number_and_optional_css_unit(
  s: String
) -> Result(#(Float, Option(CSSUnit)), Nil) {
  let assert Ok(digits_pattern) = regexp.from_string("^([-0-9.e]+)(|px|rem|em)$")

  case regexp.scan(digits_pattern, s) {
    [regexp.Match(_, [Some(digits), Some(unit)])] -> {
      let assert Ok(number) = parse_to_float(digits)
      Ok(#(number, css_unit_from_string(unit)))
    }
    _ -> Error(Nil)
  }
}

pub fn latex_inline_delimiter_pairs_list(
) -> List(LatexDelimiterPair) {
  [SingleDollar, BackslashParenthesis]
}

pub fn latex_display_delimiter_pairs_list(
) -> List(LatexDelimiterPair) {
  [DoubleDollar, BackslashSquareBracket]
}

pub fn latex_delimiter_pairs_list(
) -> List(LatexDelimiterPair) {
  [DoubleDollar, SingleDollar, BackslashParenthesis, BackslashSquareBracket]
}

pub fn opening_and_closing_string_for_pair(
  pair: LatexDelimiterPair
) -> #(String, String) {
  case pair {
    DoubleDollar -> #("$$", "$$")
    SingleDollar -> #("$", "$")
    BackslashParenthesis -> #("\\(", "\\)")
    BackslashSquareBracket -> #("\\[", "\\]")
  }
}

pub fn opening_and_closing_singletons_for_pair(
  pair: LatexDelimiterPair
) -> #(LatexDelimiterSingleton, LatexDelimiterSingleton) {
  case pair {
    DoubleDollar -> #(DoubleDollarSingleton, DoubleDollarSingleton)
    SingleDollar -> #(SingleDollarSingleton, SingleDollarSingleton)
    BackslashParenthesis -> #(BackslashOpeningParenthesis, BackslashClosingParenthesis)
    BackslashSquareBracket -> #(BackslashOpeningSquareBracket, BackslashClosingSquareBracket)
  }
}

pub fn tag_is_one_of(node: VXML, tags: List(String)) -> Bool {
  case node {
    T(_, _) -> False
    V(_, tag, _, _) -> list.contains(tags, tag)
  }
}

pub fn list_set(ze_list: List(a), index: Int, element: a) -> List(a) {
  let assert True = 0 <= index && index <= list.length(ze_list)
  let prefix = list.take(ze_list, index)
  let suffix = list.drop(ze_list, index + 1)
  [
    prefix,
    [element],
    suffix,
  ] |> list.flatten
}

pub fn get_at(ze_list: List(a), index: Int) -> Result(a, Nil) {
  case index >= list.length(ze_list) || index < 0 {
    True -> Error(Nil)
    False -> list.drop(ze_list, index) |> list.first
  }
}

pub fn trim_starting_spaces_except_first_line(vxml: VXML) {
  let assert T(blame, lines) = vxml
  let assert [first_line, ..rest] = lines
  let updated_rest =
    rest
    |> list.map(fn(line) {
      BlamedContent(..line, content: string.trim_start(line.content))
    })

  T(blame, [first_line, ..updated_rest])
}

pub fn trim_ending_spaces_except_last_line(vxml: VXML) {
  let assert T(blame, lines) = vxml
  let assert [last_line, ..rest] = lines |> list.reverse()
  let updated_rest =
    rest
    |> list.map(fn(line) {
      BlamedContent(..line, content: string.trim_end(line.content))
    })
  T(blame, list.reverse([last_line, ..updated_rest]))
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

pub fn on_lazy_none_on_some(
  over option: Option(a),
  with_on_none f1: fn() -> b,
  with_on_some f2: fn(a) -> b,
) -> b {
  case option {
    None -> f1()
    Some(z) -> f2(z)
  }
}

pub fn on_some_on_none(
  over option: Option(a),
  with_on_some f2: fn(a) -> b,
  with_on_none f1: fn() -> b,
) -> b {
  case option {
    None -> f1()
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

pub fn on_ok_on_error(
  over res: Result(a, b),
  with_on_ok f1: fn(a) -> c,
  with_on_error f2: fn(b) -> c,
) -> c {
  case res {
    Ok(r) -> f1(r)
    Error(e) -> f2(e)
  }
}

pub fn on_empty_on_nonempty(l: List(a), f1: c, f2: fn(a, List(a)) -> c) -> c {
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

pub fn on_t_on_v_no_deconstruct(
  node: VXML,
  f1: fn(Blame, List(BlamedContent)) -> c,
  f2: fn() -> c,
) -> c {
  case node {
    T(blame, blamed_contents) -> f1(blame, blamed_contents)
    _ -> f2()
  }
}

pub fn io_debug_digests(vxmls: List(VXML), announce: String) -> List(VXML) {
  io.print(announce <> ": ")
  list.each(vxmls, fn(vxml) { io.print(digest(vxml)) })
  io.println("")
  vxmls
}

pub fn set_tag(vxml: VXML, tag: String) -> VXML {
  let assert V(_, _, _, _) = vxml
  V(..vxml, tag: tag)
}

pub fn readable_attribute(attr: BlamedAttribute) -> String {
  "   " <> attr.key <> "=" <> attr.value
}

pub fn v_readable_attribute(vxml: VXML) -> String {
  let assert V(_, _, attributes, _) = vxml
  attributes
  |> list.map(readable_attribute)
  |> string.join("\n")
}

pub fn v_echo_readable_attributes(vxml: VXML) -> Nil {
  let assert V(_, _, attributes, _) = vxml
  attributes
  |> list.map(readable_attribute)
  |> list.each(fn(s) {echo s})
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

pub fn get_root_with_desugaring_error(vxmls: List(VXML)) -> Result(VXML, DesugaringError) {
  get_root(vxmls)
  |> result.map_error(fn(msg) { DesugaringError(blamedlines.empty_blame(), msg)})
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

pub fn get_contained(from: List(a), in: List(a)) -> Option(a) {
  case from {
    [] -> None
    [first, ..rest] -> case list.contains(in, first) {
      True -> Some(first)
      False -> get_contained(rest, in)
    }
  }
}

pub fn is_tag(vxml: VXML, tag: String) -> Bool {
  case vxml {
    T(_, _) -> False
    V(_, t, _, _) -> t == tag
  }
}

pub fn blame_tag_attrs_2_v(
  blamestring: String,
  tag: String,
  attrs: List(#(String, String)),
) -> VXML {
  let blame = blame_us(blamestring)
  let attrs = list.map(attrs, fn(pair) { BlamedAttribute(blame, pair.0, pair.1) })
  V(
    blame,
    tag,
    attrs,
    [],
  )
}

//**************************************************************
//* dictionary-building functions
//**************************************************************

pub fn validate_unique_keys(
  l: List(#(a, b))
) -> Result(List(#(a, b)), DesugaringError) {
  case get_duplicate(list.map(l, pair.first)) {
    Some(guy) -> Error(DesugaringError(blamedlines.empty_blame(), "duplicate key in list being converted to dict: " <> ins(guy)))
    None -> Ok(l)
  }
}

pub fn dict_from_list_with_desugaring_error(
  l: List(#(a, b))
) -> Result(Dict(a, b), DesugaringError) {
  validate_unique_keys(l)
  |> result.map(dict.from_list(_))
}

pub fn aggregate_on_first(l: List(#(a, b))) -> Dict(a, List(b)) {
  list.fold(l, dict.from_list([]), fn(d, pair) {
    let #(a, b) = pair
    case dict.get(d, a) {
      Error(Nil) -> dict.insert(d, a, [b])
      Ok(prev_list) -> dict.insert(d, a, [b, ..prev_list])
    }
  })
}

pub fn quadruples_to_pairs_pairs(
  l: List(#(a, b, c, d)),
) -> List(#(#(a, b), #(c, d))) {
  l
  |> list.map(fn(quad) {
    let #(a, b, c, d) = quad
    #(#(a, b), #(c, d))
  })
}

pub fn quad_drop_3rd(t: #(a, b, c, d)) -> #(a, b, d) {
  #(t.0, t.1, t.3)
}

pub fn quad_drop_4th(t: #(a, b, c, d)) -> #(a, b, c) {
  #(t.0, t.1, t.2)
}

pub fn triple_drop_2nd(t: #(a, b, c)) -> #(a, c) {
  #(t.0, t.2)
}

pub fn triple_drop_3rd(t: #(a, b, c)) -> #(a, b) {
  #(t.0, t.1)
}

pub fn triples_to_pairs(l: List(#(a, b, c))) -> List(#(a, #(b, c))) {
  l
  |> list.map(fn(t) {#(t.0, #(t.1, t.2))})
}

pub fn quads_to_pairs(l: List(#(a, b, c, d))) -> List(#(a, #(b, c, d))) {
  l
  |> list.map(fn(quad) {
    #(quad.0, #(quad.1, quad.2, quad.3))
  })
}

pub fn triples_to_dict(l: List(#(a, b, c))) -> Dict(a, #(b, c)) {
  l
  |> triples_to_pairs
  |> dict.from_list
}

pub fn triples_to_aggregated_dict(l: List(#(a, b, c))) -> Dict(a, List(#(b, c))) {
  l
  |> triples_to_pairs
  |> aggregate_on_first
}

pub fn use_list_pair_as_dict(
  list_pairs: List(#(a, b)),
  key: a
) -> Result(b, Nil) {
  case list_pairs {
    [] -> Error(Nil)
    [#(alice, bob), ..] if alice == key -> Ok(bob)
    [_, ..rest] -> use_list_pair_as_dict(rest, key)
  }
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

pub fn on_either_on_or(t: EitherOr(a, b), fn1: fn(a) -> c, fn2: fn(b) -> c) -> c {
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
  |> list.map(fn(thing) {
    case thing {
      Either(load) -> Either(load)
      Or(b) -> Or(f(b))
    }
  })
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

pub fn first_rest(l: List(a)) -> Result(#(a, List(a)), Nil) {
  case l {
    [first, ..rest] -> Ok(#(first, rest))
    _ -> Error(Nil)
  }
}

pub fn first_second_rest(l: List(a)) -> Result(#(a, a, List(a)), Nil) {
  case l {
    [first, second, ..rest] -> Ok(#(first, second, rest))
    _ -> Error(Nil)
  }
}

pub fn head_last(l: List(a)) -> Result(#(List(a), a), Nil) {
  case l {
    [] -> Error(Nil)
    [last] -> Ok(#([], last))
    [first, ..rest] -> {
      let assert Ok(#(head, last)) = head_last(rest)
      Ok(#([first, ..head], last))
    }
  }
}

/// dumps the contents of 'from' "upside-down" into
/// 'into', so that the first element of 'from' ends
/// up buried inside the resulting list, while the last
/// element of 'from' ends up surfaced as the first
/// element of the result
pub fn pour(from: List(a), into: List(a)) -> List(a) {
  case from {
    [first, ..rest] -> pour(rest, [first, ..into])
    [] -> into
  }
}

pub fn index_map_fold(
  list: List(a),
  initial_acc: b,
  f: fn(b, a, Int) -> #(b, c),
) -> #(b, List(c)) {
  list.index_fold(list, #(initial_acc, []), fn(acc, item, index) {
    let #(current_acc, results) = acc
    let #(new_acc, result) = f(current_acc, item, index)
    #(new_acc, [result, ..results])
  })
  |> pair.map_second(list.reverse)
}

pub fn try_map_fold(
  over ze_list: List(q),
  from state: a,
  with f: fn(a, q) -> Result(#(q, a), c)
) -> Result(#(List(q), a), c) {
  case ze_list {
    [] -> Ok(#([], state))
    [first, ..rest] -> {
      use #(mapped_first, state) <- result.try(f(state, first))
      use #(mapped_rest, state) <- result.try(try_map_fold(rest, state, f))
      Ok(#([mapped_first, ..mapped_rest], state))
    }
  }
}

//**************************************************************
//* find replace list-version
//**************************************************************

fn find_replace_in_blamed_content(
  blamed_content: BlamedContent,
  list_pairs: List(#(String, String)),
) -> BlamedContent {
  use #(first_from, first_to), rest <- on_empty_on_nonempty(
    list_pairs,
    blamed_content,
  )
  BlamedContent(
    blamed_content.blame,
    string.replace(blamed_content.content, first_from, first_to),
  )
  |> find_replace_in_blamed_content(rest)
}

pub fn find_replace_in_t(node: VXML, list_pairs: List(#(String, String))) {
  let assert T(blame, blamed_contents) = node
  T(
    blame,
    blamed_contents |> list.map(find_replace_in_blamed_content(_, list_pairs)),
  )
}

pub fn find_replace_in_node(
  node: VXML,
  list_pairs: List(#(String, String)),
) -> VXML {
  case node {
    T(_, _) -> find_replace_in_t(node, list_pairs)
    _ -> node
  }
}

//**************************************************************
//* find replace no_list-version
//**************************************************************

pub fn find_replace_in_t_no_list(
  node: VXML,
  from: String,
  to: String,
) -> VXML {
  let assert T(blame, contents) = node
  T(
    blame,
    list.map(
      contents,
      fn(bc){BlamedContent(bc.blame, string.replace(bc.content, from, to))}
    )
  )
}

pub fn find_replace_in_node_no_list(
  node: VXML,
  from: String,
  to: String,
) -> VXML {
  case node {
    T(_, _) -> find_replace_in_t_no_list(node, from, to)
    _ -> node
  }
}

//**************************************************************
//* blame-related                                              *
//**************************************************************

pub const no_blame = Blame("", -1, -1, [])

pub fn blame_us(message: String) -> Blame {
    Blame(message, 0, 0, [])
}

pub fn get_blame(vxml: VXML) -> Blame {
  case vxml {
    T(blame, _) -> blame
    V(blame, _, _, _) -> blame
  }
}

pub fn assert_get_first_blame(vxmls: List(VXML)) -> Blame {
  let assert [first, ..] = vxmls
  get_blame(first)
}

pub fn append_blame_comment(blame: Blame, comment: String) -> Blame {
  let Blame(filename, indent, char_no, comments) = blame
  Blame(filename, indent, char_no, [comment, ..comments])
}

//**************************************************************
//* misc (children collecting, inserting, ...)
//**************************************************************

fn lines_last_to_first_concatenation_where_first_lines_are_already_reversed(
  l1: List(BlamedContent),
  l2: List(BlamedContent),
) -> List(BlamedContent) {
  let assert [first1, ..rest1] = l1
  let assert [first2, ..rest2] = l2
  pour(
    rest1,
    [
      BlamedContent(first1.blame, first1.content <> first2.content),
      ..rest2
    ]
  )
}

pub fn last_to_first_concatenation_in_list_list_of_lines_where_all_but_last_list_are_already_reversed(
  list_of_lists: List(List(BlamedContent))
) -> List(BlamedContent) {
  case list_of_lists {
    [] -> panic as "this is unexpected"
    [one] -> one
    [next_to_last, last] -> lines_last_to_first_concatenation_where_first_lines_are_already_reversed(next_to_last, last)
    [first, ..rest] -> lines_last_to_first_concatenation_where_first_lines_are_already_reversed(
      first,
      last_to_first_concatenation_in_list_list_of_lines_where_all_but_last_list_are_already_reversed(rest)
    )
  }
}

pub fn t_t_last_to_first_concatenation(node1: VXML, node2: VXML) -> VXML {
  let assert T(blame1, lines1) = node1
  let assert T(_, lines2) = node2
  T(
    blame1,
    lines_last_to_first_concatenation_where_first_lines_are_already_reversed(
      lines1 |> list.reverse,
      lines2
    )
  )
}

fn last_to_first_concatenation_internal(
  remaining: List(VXML),
  already_done: List(VXML),
  current_t: Option(VXML)
) {
  case remaining {
    [] -> case current_t {
      None -> already_done |> list.reverse
      Some(t) -> [t, ..already_done] |> list.reverse
    }
    [V(_, _, _, _) as first, ..rest] -> case current_t {
      None -> last_to_first_concatenation_internal(
        rest,
        [first, ..already_done],
        None
      )
      Some(t) -> last_to_first_concatenation_internal(
        rest,
        [first, t, ..already_done],
        None,
      )
    }
    [T(_, _) as first, ..rest] -> case current_t {
      None -> last_to_first_concatenation_internal(
        rest,
        already_done,
        Some(first)
      )
      Some(t) -> last_to_first_concatenation_internal(
        rest,
        already_done,
        Some(t_t_last_to_first_concatenation(t, first))
      )
    }
  }
}

pub fn last_to_first_concatenation(vxmls: List(VXML)) -> List(VXML) {
  last_to_first_concatenation_internal(vxmls, [], None)
}

pub fn v_last_to_first_concatenation(v: VXML) -> VXML {
  let assert V(blame, tag, attributes, children) = v
  let children = last_to_first_concatenation(children)
  V(blame, tag, attributes, children)
}

fn nonempty_list_t_plain_concatenation(nodes: List(VXML)) -> VXML {
  let assert [first, ..] = nodes
  let assert T(blame, _) = first
  let all_lines = {
    nodes
    |> list.map(fn(node) {
      let assert T(_, blamed_lines) = node
      blamed_lines
    })
    |> list.flatten
  }
  T(blame, all_lines)
}

pub fn plain_concatenation_in_list(nodes: List(VXML)) -> List(VXML) {
  nodes
  |> either_or_misceginator(is_text_node)
  |> regroup_eithers_no_empty_lists
  |> map_either_ors(
    fn(either: List(VXML)) -> VXML { nonempty_list_t_plain_concatenation(either) },
    fn(or: VXML) -> VXML { or },
  )
}

pub fn lines_remove_starting_empty_lines(l: List(BlamedContent)) -> List(BlamedContent) {
  case l {
    [] -> []
    [first, ..rest] ->
      case first.content {
        "" -> lines_remove_starting_empty_lines(rest)
        _ -> l
      }
  }
}

pub fn debug_lines_and(
  lines: List(BlamedContent),
  announcer: String,
) -> List(BlamedContent) {
  io.print(announcer <> ":" <> string.repeat(" ", 15 - string.length(announcer)))
  list.index_map(
    lines,
    fn(line, i) {
      case i > 0 {
        True -> io.print(string.repeat(" ", 16))
        False -> Nil
      }
      io.println("\"" <> line.content <> "\"")
    }
  )
  lines
}

fn split_lines_internal(
  previous_splits: List(List(BlamedContent)),
  current_lines: List(BlamedContent),
  remaining: List(BlamedContent),
  splitter: String,
) -> List(List(BlamedContent)) {
  case remaining {
    [] -> [
      current_lines |> list.reverse,
      ..previous_splits
    ] |> list.reverse
    [first, ..rest] -> {
      case string.split_once(first.content, splitter) {
        Error(_) -> split_lines_internal(
          previous_splits,
          [first, ..current_lines],
          rest,
          splitter,
        )
        Ok(#(before, after)) -> split_lines_internal(
          [
            [
              BlamedContent(first.blame, before),
              ..current_lines
            ] |> list.reverse,
            ..previous_splits,
          ],
          [],
          [
            BlamedContent(first.blame, after),
            ..rest,
          ],
          splitter,
        )
      }
    }
  }
}

pub fn split_lines(
  lines: List(BlamedContent),
  splitter: String,
) -> List(List(BlamedContent)) {
  split_lines_internal(
    [],
    [],
    lines,
    splitter,
  )
}

pub fn lines_trim_start(
  lines: List(BlamedContent),
) -> List(BlamedContent) {
  case lines {
    [] -> []
    [first, ..rest] -> {
      case string.first(first.content) {
        Error(_) -> lines_trim_start(rest)
        Ok(" ") -> case string.trim_start(first.content) {
          "" -> lines_trim_start(rest)
          nonempty -> [BlamedContent(first.blame, nonempty), ..rest]
        }
        _ -> lines
      }
    }
  }
}

pub fn reversed_lines_trim_end(
  lines: List(BlamedContent),
) -> List(BlamedContent) {
  case lines {
    [] -> []
    [first, ..rest] -> {
      case string.last(first.content) {
        Error(_) -> reversed_lines_trim_end(rest)
        Ok(" ") -> case string.trim_end(first.content) {
          "" -> reversed_lines_trim_end(rest)
          nonempty -> reversed_lines_trim_end([BlamedContent(first.blame, nonempty), ..rest])
        }
        _ -> lines
      }
    }
  }
}

pub fn first_line_starts_with(
  lines: List(BlamedContent),
  s: String,
) -> Bool {
  case lines {
    [] -> False
    [BlamedContent(_, line), ..] -> string.starts_with(line, s)
  }
}

pub fn first_line_ends_with(
  lines: List(BlamedContent),
  s: String,
) -> Bool {
  case lines {
    [] -> False
    [BlamedContent(_, line), ..] -> string.ends_with(line,s)
  }
}

pub fn t_remove_starting_empty_lines(vxml: VXML) -> Option(VXML) {
  let assert T(blame, lines) = vxml
  let lines = lines_remove_starting_empty_lines(lines)
  case lines {
    [] -> None
    _ -> Some(T(blame, lines))
  }
}

pub fn t_remove_ending_empty_lines(vxml: VXML) -> Option(VXML) {
  let assert T(blame, lines) = vxml
  let lines = lines_remove_starting_empty_lines(lines |> list.reverse) |> list.reverse
  case lines {
    [] -> None
    _ -> Some(T(blame, lines))
  }
}

pub fn extract_starting_spaces_from_text(content: String) -> #(String, String) {
  let new_content = string.trim_start(content)
  let num_spaces = string.length(content) - string.length(new_content)
  #(string.repeat(" ", num_spaces), new_content)
}

pub fn extract_ending_spaces_from_text(content: String) -> #(String, String) {
  let new_content = string.trim_end(content)
  let num_spaces = string.length(content) - string.length(new_content)
  #(string.repeat(" ", num_spaces), new_content)
}

pub fn t_trim_start(node: VXML) -> Option(VXML) {
  let assert T(blame, lines) = node
  case lines_trim_start(lines) {
    [] -> None
    lines -> Some(T(blame, lines))
  }
}

pub fn t_trim_end(node: VXML) -> Option(VXML) {
  let assert T(blame, lines) = node
  case reversed_lines_trim_end(lines |> list.reverse) {
    [] -> None
    lines -> Some(T(blame, lines |> list.reverse))
  }
}

pub fn t_super_trim_end(node: VXML) -> Option(VXML) {
  let assert T(blame, blamed_contents) = node
  let blamed_contents =
    blamed_contents
    |> list.reverse
    |> list.take_while(fn(bc) { string.trim_end(bc.content) == "" })
  case blamed_contents {
    [] -> None
    _ -> Some(T(blame, blamed_contents |> list.reverse))
  }
}

pub fn t_super_trim_end_and_remove_ending_period(node: VXML) -> Option(VXML) {
  let assert T(blame, blamed_contents) = node

  let blamed_contents =
    blamed_contents
    |> list.reverse
    |> list.drop_while(fn(bc) { string.trim_end(bc.content) == "" })

  case blamed_contents {
    [] -> None
    [last, ..rest] -> {
      let content = string.trim_end(last.content)
      case string.ends_with(content, ".") && !string.ends_with(content, "..") {
        True -> {
          let last = BlamedContent(..last, content: {content |> string.drop_end(1)})
          T(blame, [last, ..rest] |> list.reverse)
          |> t_super_trim_end_and_remove_ending_period
        }
        False -> Some(T(blame, [last, ..rest] |> list.reverse))
      }
    }
  }
}

pub fn t_drop_start(node: VXML, to_drop: Int) -> VXML {
  let assert T(blame, blamed_contents) = node
  let assert [first, ..rest] = blamed_contents
  T(blame, [BlamedContent(first.blame, string.drop_start(first.content, to_drop) ), ..rest])
}

pub fn t_drop_end(node: VXML, to_drop: Int) -> VXML {
  let assert T(blame, blamed_contents) = node
  let assert [first, ..rest] = blamed_contents |> list.reverse
  T(blame, [BlamedContent(first.blame, string.drop_end(first.content, to_drop) ), ..rest] |> list.reverse)
}

pub fn t_extract_starting_spaces(node: VXML) -> #(Option(VXML), VXML) {
  let assert T(blame, blamed_contents) = node
  let assert [first, ..rest] = blamed_contents
  case extract_starting_spaces_from_text(first.content) {
    #("", _) -> #(None, node)
    #(spaces, not_spaces) -> #(
      Some(T(first.blame, [BlamedContent(first.blame, spaces)])),
      T(blame, [BlamedContent(first.blame, not_spaces), ..rest]),
    )
  }
}

pub fn t_extract_ending_spaces(node: VXML) -> #(Option(VXML), VXML) {
  let assert T(blame, blamed_contents) = node
  let assert [first, ..rest] = blamed_contents |> list.reverse
  case extract_ending_spaces_from_text(first.content) {
    #("", _) -> #(None, node)
    #(spaces, not_spaces) -> #(
      Some(T(first.blame, [BlamedContent(first.blame, spaces)])),
      T(blame, [BlamedContent(first.blame, not_spaces), ..rest] |> list.reverse),
    )
  }
}

pub fn v_extract_starting_spaces(node: VXML) -> #(Option(VXML), VXML) {
  let assert V(blame, tag, attrs, children) = node
  case children {
    [T(_, _) as first, ..rest] -> {
      case t_extract_starting_spaces(first) {
        #(None, _) -> #(None, node)
        #(Some(guy), first) -> #(
          Some(guy),
          V(blame, tag, attrs, [first, ..rest]),
        )
      }
    }
    _ -> #(None, node)
  }
}

pub fn v_extract_ending_spaces(node: VXML) -> #(Option(VXML), VXML) {
  let assert V(blame, tag, attrs, children) = node
  case children |> list.reverse {
    [T(_, _) as first, ..rest] -> {
      case t_extract_ending_spaces(first) {
        #(None, _) -> #(None, node)
        #(Some(guy), first) -> #(
          Some(guy),
          V(blame, tag, attrs, [first, ..rest] |> list.reverse),
        )
      }
    }
    _ -> #(None, node)
  }
}

pub fn v_trim_start(node: VXML) -> VXML {
  let assert V(_, _, _, children) = node
  case children {
    [T(_, _) as first, ..rest] -> {
      case t_trim_start(first) {
        None -> v_trim_start(V(..node, children: rest))
        Some(guy) -> V(..node, children: [guy, ..rest])
      }
    }
    _ -> node
  }
}

pub fn v_trim_end(node: VXML) -> VXML {
  let assert V(_, _, _, children) = node
  case children |> list.reverse {
    [T(_, _) as first, ..rest] -> {
      case t_trim_end(first) {
        None -> v_trim_end(V(..node, children: rest |> list.reverse))
        Some(guy) -> V(..node, children: [guy, ..rest] |> list.reverse)
      }
    }
    _ -> node
  }
}

pub fn v_remove_starting_empty_lines(node: VXML) -> VXML {
  let assert V(_, _, _, children) = node
  case children {
    [T(_, _) as first, ..rest] -> {
      case t_remove_starting_empty_lines(first) {
        None -> v_remove_starting_empty_lines(V(..node, children: rest))
        Some(guy) -> V(..node, children: [guy, ..rest])
      }
    }
    _ -> node
  }
}

pub fn v_remove_ending_empty_lines(node: VXML) -> VXML {
  let assert V(_, _, _, children) = node
  case children |> list.reverse {
    [T(_, _) as first, ..rest] -> {
      case t_remove_ending_empty_lines(first) {
        None -> v_remove_ending_empty_lines(V(..node, children: rest |> list.reverse))
        Some(guy) -> V(..node, children: [guy, ..rest] |> list.reverse)
      }
    }
    _ -> node
  }
}

pub fn encode_starting_spaces_in_string(content: String) -> String {
  let new_content = string.trim_start(content)
  let num_spaces = string.length(content) - string.length(new_content)
  string.repeat("&ensp;", num_spaces) <> new_content
}

pub fn encode_ending_spaces_in_string(content: String) -> String {
  let new_content = string.trim_end(content)
  let num_spaces = string.length(content) - string.length(new_content)
  new_content <> string.repeat("&ensp;", num_spaces)
}

pub fn encode_starting_spaces_in_blamed_content(
  blamed_content: BlamedContent,
) -> BlamedContent {
  BlamedContent(
    blamed_content.blame,
    blamed_content.content |> encode_starting_spaces_in_string,
  )
}

pub fn encode_ending_spaces_in_blamed_content(
  blamed_content: BlamedContent,
) -> BlamedContent {
  BlamedContent(
    blamed_content.blame,
    blamed_content.content |> encode_ending_spaces_in_string,
  )
}

pub fn encode_starting_spaces_if_text(vxml: VXML) -> VXML {
  case vxml {
    V(_, _, _, _) -> vxml
    T(blame, blamed_contents) -> {
      let assert [first, ..rest] = blamed_contents
      T(blame, [first |> encode_starting_spaces_in_blamed_content, ..rest])
    }
  }
}

pub fn encode_ending_spaces_if_text(vxml: VXML) -> VXML {
  case vxml {
    V(_, _, _, _) -> vxml
    T(blame, blamed_contents) -> {
      let assert [last, ..rest] = {
        blamed_contents |> list.reverse
      }
      T(
        blame,
        [last |> encode_ending_spaces_in_blamed_content, ..rest]
          |> list.reverse,
      )
    }
  }
}

pub fn encode_starting_spaces_in_first_node(vxmls: List(VXML)) -> List(VXML) {
  case vxmls {
    [] -> []
    [first, ..rest] -> [first |> encode_starting_spaces_if_text, ..rest]
  }
}

pub fn encode_ending_spaces_in_last_node(vxmls: List(VXML)) -> List(VXML) {
  case vxmls |> list.reverse {
    [] -> []
    [last, ..rest] ->
      [last |> encode_ending_spaces_if_text, ..rest]
      |> list.reverse
  }
}

pub fn t_start_insert_text(node: VXML, text: String) {
  let assert T(blame, lines) = node
  let assert [BlamedContent(blame_first, content_first), ..other_lines] = lines
  T(
    blame,
    [BlamedContent(blame_first, text <> content_first), ..other_lines]
  )
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
    [
      T(_, _) as first, ..rest
    ] -> [
      t_start_insert_text(first, text), ..rest
    ]
    _ -> [
      T(blame, [BlamedContent(blame, text)]), ..vxmls
    ]
  }
}

pub fn list_end_insert_text(
  blame: Blame,
  vxmls: List(VXML),
  text: String,
) -> List(VXML) {
  case vxmls |> list.reverse {
    [T(_, _) as first, ..rest] ->
      [t_end_insert_text(first, text), ..rest]
      |> list.reverse
    _ ->
      [T(blame, [BlamedContent(blame, text)]), ..vxmls]
      |> list.reverse
  }
}

pub fn v_start_insert_text(node: VXML, text: String) -> VXML {
  let assert V(blame, tag, attrs, children) = node
  {
    let children = list_start_insert_text(blame, children, text)
    V(blame, tag, attrs, children)
  }
}

pub fn v_end_insert_text(node: VXML, text: String) -> VXML {
  let assert V(blame, tag, attrs, children) = node
  {
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
      { " " <> rest } |> string.reverse,
      yoro |> string.reverse,
    )
    _ -> #("", input)
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
          let contents =
            [BlamedContent(last.blame, before_last_word), ..rest]
            |> list.reverse
          #(
            T(blame, contents),
            Some(T(last.blame, [BlamedContent(last.blame, last_word)])),
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
            T(blame, contents),
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

pub fn kabob_case_to_camel_case(input: String) -> String {
  input
  |> string.split("-")
  |> list.index_map(fn(word, index) {
    case index {
      0 -> word
      _ -> case string.to_graphemes(word) {
        [] -> ""
        [first, ..rest] -> string.uppercase(first) <> string.join(rest, "")
      }
    }
  })
  |> string.join("")
}

pub fn prepend_attribute(vxml: VXML, attr: BlamedAttribute) {
  let assert V(blame, tag, attrs, children) = vxml
  V(blame, tag, [attr, ..attrs], children)
}

pub fn prepend_unique_key_attribute(
  vxml: VXML,
  attr: BlamedAttribute,
) -> Result(VXML, Nil) {
  case v_has_attribute_with_key(vxml, attr.key) {
    True -> Error(Nil)
    False -> Ok(prepend_attribute(vxml, attr))
  }
}

pub fn prepend_child(vxml: VXML, child: VXML) {
  let assert V(blame, tag, attributes, children) = vxml
  V(blame, tag, attributes, [child, ..children])
}

pub fn get_attribute_keys(attrs: List(BlamedAttribute)) -> List(String) {
  attrs
  |> list.map(fn(attr) { attr.key })
}

pub fn v_attribute_with_key(
  vxml: VXML,
  key: String,
) -> Option(BlamedAttribute) {
  let assert V(_, _, attrs, _) = vxml
  case list.find(attrs, fn(b) { b.key == key })
  {
    Error(Nil) -> None
    Ok(thing) -> Some(thing)
  }
}

pub fn v_all_attributes_with_key(
  vxml: VXML,
  key: String,
) -> List(BlamedAttribute) {
  let assert V(_, _, attrs, _) = vxml
  attrs
  |> list.filter(fn(b) {b.key == key})
}

pub fn v_has_attribute_with_key(vxml: VXML, key: String) -> Bool {
  let assert V(_, _, attrs, _) = vxml
  case list.find(attrs, fn(b) { b.key == key }) {
    Error(Nil) -> False
    Ok(_) -> True
  }
}

pub fn v_has_key_value(vxml: VXML, key: String, value: String) -> Bool {
  let assert V(_, _, attrs, _) = vxml
  case list.find(attrs, fn(b) { b.key == key && b.value == value }) {
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
    V(_, t, _, _) -> t == tag
  }
}

pub fn is_v_and_tag_is_one_of(vxml: VXML, tags: List(String)) -> Bool {
  case vxml {
    T(_, _) -> False
    V(_, tag, _, _) -> list.contains(tags, tag)
  }
}

pub fn is_v_and_has_key_value(vxml: VXML, key: String, value: String) -> Bool {
  case vxml {
    T(_, _) -> False
    _ -> {
      v_has_key_value(vxml, key, value)
    }
  }
}

pub fn get_tag(vxml: VXML) -> String {
  let assert V(_, tag, _, _) = vxml
  tag
}

pub fn extract_tag(vxml: VXML) -> String {
  let assert V(_, tag, _, _) = vxml
  tag
}

pub fn is_text_node(node: VXML) -> Bool {
  case node {
    T(_, _) -> True
    V(_, _, _, _) -> False
  }
}

pub fn is_text_or_is_one_of(node: VXML, tags: List(String)) -> Bool {
  case node {
    T(_, _) -> True
    V(_, tag, _, _) -> list.contains(tags, tag)
  }
}

pub fn filter_children(vxml: VXML, condition: fn(VXML) -> Bool) -> List(VXML) {
  let assert V(_, _, _, children) = vxml
  list.filter(children, condition)
}

pub fn filter_descendants(vxml: VXML, condition: fn(VXML) -> Bool) -> List(VXML) {
  case vxml {
    T(_, _) -> []
    V(_, _, _, children) -> {
      let matching_children = list.filter(children, condition)
      let descendants_from_children =
        list.map(children, filter_descendants(_, condition))
        |> list.flatten

      list.flatten([
        matching_children,
        descendants_from_children,
      ])
    }
  }
}

pub fn children_with_tag(vxml: VXML, tag: String) -> List(VXML) {
  let assert V(_, _, _, _) = vxml
  filter_children(vxml, is_v_and_tag_equals(_, tag))
}

pub fn children_with_tags(vxml: VXML, tags: List(String)) -> List(VXML) {
  let assert V(_, _, _, _) = vxml
  filter_children(vxml, fn (node){ tags |> list.any(is_v_and_tag_equals(node, _)) })
}

pub fn children_with_class(vxml: VXML, class: String) -> List(VXML) {
  let assert V(_, _, _, _) = vxml
  filter_children(vxml, has_class(_, class))
}

pub fn index_of(ze_list: List(a), thing: a) -> Int {
  index_of_internal(ze_list, thing, 0)
}

fn index_of_internal(ze_list: List(a), thing: a, current_index: Int) -> Int {
  case ze_list {
    [] -> -1
    [first, ..] if first == thing -> current_index
    [_, ..rest] -> index_of_internal(rest, thing, current_index + 1)
  }
}

pub fn index_filter_children(
  vxml: VXML,
  condition: fn(VXML) -> Bool,
) -> List(#(VXML, Int)) {
  let assert V(_, _, _, children) = vxml
  children
  |> list.filter(condition)
  |> list.index_map(fn(v, idx) { #(v, idx) })
}

pub fn index_children_with_tag(vxml: VXML, tag: String) -> List(#(VXML, Int)) {
  index_filter_children(vxml, is_v_and_tag_equals(_, tag))
}

pub fn descendants_with_tag(vxml: VXML, tag: String) -> List(VXML) {
  filter_descendants(vxml, is_v_and_tag_equals(_, tag))
}

pub fn descendants_with_key_value(vxml: VXML, attr_key: String, attr_value: String) -> List(VXML) {
  filter_descendants(vxml, is_v_and_has_key_value(_, attr_key, attr_value))
}

pub fn descendants_with_class(vxml: VXML, class: String) -> List(VXML) {
  filter_descendants(vxml, has_class(_, class))
}

pub fn excise_children(node: VXML, condition: fn(VXML) -> Bool) -> #(VXML, List(VXML)) {
  let assert V(blame, tag, attributes, children) = node
  let #(remaining_children, excised_children) = list.partition(children, fn(child) { !condition(child) })
  let new_node = V(blame, tag, attributes, remaining_children)
  #(new_node, excised_children)
}

pub fn replace_children_with(node: VXML, children: List(VXML)) {
  case node {
    V(b, t, a, _) -> V(b, t, a, children)
    _ -> node
  }
}

pub fn assert_pop_attribute(vxml: VXML, key: String) -> #(VXML, BlamedAttribute) {
  let assert V(b, t, a, c) = vxml
  let assert #([unique_guy_with_key], other_guys) = list.partition(a, fn(b){b.key == key})
  #(V(b, t, other_guys, c), unique_guy_with_key)
}

pub fn assert_pop_attribute_value(vxml: VXML, key: String) -> #(VXML, String) {
  let #(vxml, BlamedAttribute(_, _, value)) = assert_pop_attribute(vxml, key)
  #(vxml, value)
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

pub fn unique_child_with_tag(
  vxml: VXML,
  tag: String,
) -> Result(VXML, SingletonError) {
  children_with_tag(vxml, tag)
  |> read_singleton
}

pub fn digest(vxml: VXML) -> String {
  case vxml {
    V(_, tag, _, _) -> "V(_, " <> tag <> ", _, _)"
    T(_, _) -> "T(_, _)"
  }
}

pub fn valid_tag(tag: String) -> Bool {
  !string.is_empty(tag) &&
  !string.contains(tag, " ") &&
  !string.contains(tag, ".") &&
  !string.contains(tag, "\n") &&
  !string.contains(tag, "\t")
}

pub fn normalize_spaces(
  s: String
) -> String {
  s
  |> string.split(" ")
  |> list.filter(fn(x){!string.is_empty(x)})
  |> string.join(" ")
}

pub fn string_pair_2_blamed_attribute(
  pair: #(String, String),
  blame: Blame,
) {
  BlamedAttribute(blame, pair.0, pair.1)
}

pub fn string_pairs_2_blamed_attributes(
  pairs: List(#(String, String)),
  blame: Blame,
) {
  pairs
  |> list.map(string_pair_2_blamed_attribute(_, blame))
}

pub fn append_if_not_present(ze_list: List(a), ze_thing: a) -> List(a) {
  case list.contains(ze_list, ze_thing) {
    True -> ze_list
    False -> list.append(ze_list, [ze_thing])
  }
}

pub fn has_class(vxml: VXML, class: String) -> Bool {
  case vxml {
    T(_, _) -> False
    _ -> {
      case v_attribute_with_key(vxml, "class") {
        Some(BlamedAttribute(_, "class", vals)) -> {
          vals
          |> string.split(" ")
          |> list.contains(class)
        }
        _ -> False
      }
    }
  }
}

pub fn concatenate_classes(a: String, b: String) -> String {
  let all_a = a |> string.split(" ") |> list.filter(fn(s){!string.is_empty(s)}) |> list.map(string.trim)
  let all_b = b |> string.split(" ") |> list.filter(fn(s){!string.is_empty(s)}) |> list.map(string.trim)
  let all = list.flatten([all_a, all_b])
  list.fold(all, [], append_if_not_present)
  |> string.join(" ")
}

pub fn append_to_class_attribute(attrs: List(BlamedAttribute), blame: Blame, classes: String) -> List(BlamedAttribute) {
  let #(index, new_attribute) = list.index_fold(
    attrs,
    #(-1, BlamedAttribute(blame, "", "")),
    fn (acc, attr, i) {
      case acc.0, attr.key {
        -1, "class" -> #(i, BlamedAttribute(..attr, value: concatenate_classes(attr.value, classes)))
        _, _ -> acc
      }
    }
  )
  case index >= 0 {
    True -> list_set(attrs, index, new_attribute)
    False -> list.append(attrs, [BlamedAttribute(blame, "class", concatenate_classes("", classes))])
  }
}

/// adds classes to a V node
pub fn v_append_classes(
  node: VXML,
  classes: String,
) -> VXML {
  let assert V(blame, _, attributes, _) = node
  V(
    ..node,
    attributes: append_to_class_attribute(attributes, blame, classes),
  )
}

/// adds classes to a V node if condition is met
pub fn v_append_classes_if(
  node: VXML,
  classes: String,
  condition: fn(VXML) -> Bool,
) -> VXML {
  case condition(node) {
    True -> v_append_classes(node, classes)
    False -> node
  }
}

/// maps over a list of VXML nodes, applying mapper only to V nodes
pub fn map_v_nodes(
  vxmls: List(VXML),
  mapper: fn(VXML) -> VXML
) -> List(VXML) {
  list.map(
    vxmls,
    fn(vxml) {
      case vxml {
        T(_, _) -> vxml
        V(_, _, _, _) -> mapper(vxml)
      }
    }
  )
}

pub fn if_else(cond: Bool, if_branch: a, else_branch: a) -> a {
  case cond {
    True -> if_branch
    False -> else_branch
  }
}

//*******************
//* assertive tests *
//*******************

pub type AssertiveTestError {
  VXMLParseError(vxml.VXMLParseError)
  TestDesugaringError(DesugaringError)
  AssertiveTestError(name: String, output: String, expected: String)
  NonMatchingDesugarerName(String)
}

pub type AssertiveTestDataNoParam {
  AssertiveTestDataNoParam(
    source: String,
    expected: String,
  )
}

pub type AssertiveTestData(a) {
  AssertiveTestData(
    param: a,
    source: String,
    expected: String,
  )
}

pub type AssertiveTestDataNoParamWithOutside {
  AssertiveTestDataNoParamWithOutside(
    outside: List(String),
    source: String,
    expected: String,
  )
}

pub type AssertiveTestDataWithOutside(a) {
  AssertiveTestDataWithOutside(
    param: a,
    outside: List(String),
    source: String,
    expected: String,
  )
}

pub type AssertiveTest {
  AssertiveTest(
    desugarer_factory: fn() -> Desugarer,
    source: String,   // VXML String
    expected: String, // VXML String
  )
}

pub type AssertiveTests {
  AssertiveTests(
    name: String,
    tests: fn() -> List(AssertiveTest),
  )
}

fn remove_minimum_indent(s: String) -> String {
  let lines = s |> string.split("\n") |> list.filter(fn(line) { string.trim(line) != "" })

  let minimum_indent =
    lines
    |> list.map(fn(line) { string.length(line) - string.length(string.trim_start(line)) })
    |> list.sort(int.compare)
    |> list.first
    |> result.unwrap(0)

  lines |> list.map(fn(line) { line |> string.drop_start(minimum_indent) }) |> string.join("\n")
}

pub fn assertive_tests_from_data_no_param(
  name: String,
  datas: List(AssertiveTestDataNoParam),
  constructor: fn() -> Desugarer,
) -> AssertiveTests {
  AssertiveTests(
    name: name,
    tests: fn() -> List(AssertiveTest) {
      list.map(
        datas,
        fn(data) {
          AssertiveTest(
            desugarer_factory: constructor,
            source: data.source |> remove_minimum_indent,
            expected: data.expected |> remove_minimum_indent
          )
        }
      )
    }
  )
}

pub fn assertive_tests_from_data(
  name: String,
  datas: List(AssertiveTestData(a)),
  constructor: fn(a) -> Desugarer,
) -> AssertiveTests {
  AssertiveTests(
    name: name,
    tests: fn() -> List(AssertiveTest) {
      list.map(
        datas,
        fn(data) {
          AssertiveTest(
            desugarer_factory: fn() { constructor(data.param) },
            source: data.source |> remove_minimum_indent,
            expected: data.expected |> remove_minimum_indent
          )
        }
      )
    }
  )
}

pub fn assertive_tests_from_data_no_param_with_outside(
  name: String,
  datas: List(AssertiveTestDataNoParamWithOutside),
  constructor: fn(List(String)) -> Desugarer,
) -> AssertiveTests {
  AssertiveTests(
    name: name,
    tests: fn() -> List(AssertiveTest) {
      list.map(
        datas,
        fn(data) {
          AssertiveTest(
            desugarer_factory: fn() { constructor(data.outside) },
            source: data.source |> remove_minimum_indent,
            expected: data.expected |> remove_minimum_indent
          )
        }
      )
    }
  )
}

pub fn assertive_tests_from_data_with_outside(
  name: String,
  datas: List(AssertiveTestDataWithOutside(a)),
  constructor: fn(a, List(String)) -> Desugarer,
) -> AssertiveTests {
  AssertiveTests(
    name: name,
    tests: fn() -> List(AssertiveTest) {
      list.map(
        datas,
        fn(data) {
          AssertiveTest(
            desugarer_factory: fn() { constructor(data.param, data.outside) },
            source: data.source |> remove_minimum_indent,
            expected: data.expected |> remove_minimum_indent
          )
        }
      )
    }
  )
}

pub fn run_assertive_test(name: String, tst: AssertiveTest) -> Result(Nil, AssertiveTestError) {
  let desugarer = tst.desugarer_factory()

  use <- on_true_on_false(
    name != desugarer.name,
    Error(NonMatchingDesugarerName(desugarer.name)),
  )

  use input <- result.try(
    vxml.unique_root_parse_string(tst.source, "test " <> desugarer.name, False)
    |> result.map_error(fn(e) { VXMLParseError(e) })
  )

  use expected <- result.try(
    vxml.unique_root_parse_string(tst.expected, "test " <> desugarer.name, False)
    |> result.map_error(fn(e) { VXMLParseError(e) })
  )

  use output <- result.try(
    desugarer.transform(input)
    |> result.map_error(fn(e) { TestDesugaringError(e) })
  )

  case vxml_to_string(output) == vxml_to_string(expected) {
    True -> Ok(Nil)
    False -> Error(
      AssertiveTestError(
        desugarer.name,
        vxml.debug_vxml_to_string("(obtained) ", output),
        vxml.debug_vxml_to_string("(expected) ", expected),
      )
    )
  }
}

pub fn run_and_announce_results(
  test_group: AssertiveTests,
  tst: AssertiveTest,
  number: Int,
  total: Int,
) -> Int {
  case run_assertive_test(test_group.name, tst) {
    Ok(Nil) -> {
      io.print("✅")
      0
    }
    Error(error) -> {
      io.print("\n❌ test " <> ins(number) <> " of " <> ins(total) <> " failed: ")
      case error {
        AssertiveTestError(_, output, expected) -> {
          io.println(" obtained != expected:")
          io.print(output)
          io.print(expected)
          Nil
        }
        _ -> io.println(ins(error))
      }
      1
    }
  }
}

pub fn run_assertive_tests(test_group: AssertiveTests) -> #(Int, Int) {
  let tests = test_group.tests()
  let total = list.length(tests)
  use <- on_false_on_true(
    total > 0,
    #(0, 0),
  )
  io.print(test_group.name <> " ")
  let #(num_success, num_failures) = list.fold(
    tests,
    #(0, 0),
    fn (acc, tst) {
      let failure = run_and_announce_results(test_group, tst, acc.0 + acc.1 + 1, total)
      #(acc.0 + 1 - failure, acc.1 + failure)
    }
  )
  case list.length(tests) == 1 {
    True -> io.println(" (1 assertive test)")
    False -> io.println(" (" <> ins(num_success) <> " assertive tests)")
  }
  #(num_success, num_failures)
}

//*********
//* types *
//*********

pub type DesugaringError {
  DesugaringError(blame: Blame, message: String)
}

pub type DesugarerTransform =
  fn(VXML) -> Result(VXML, DesugaringError)

pub type Desugarer {
  Desugarer(
    name: String,
    stringified_param: Option(String),
    stringified_outside: Option(String),
    docs: String,
    transform: DesugarerTransform,
  )
}

pub type InSituDesugaringError {
  InSituDesugaringError(
    desugarer: Desugarer,
    pipeline_step: Int,
    message: String,
    blame: Blame,
  )
}
