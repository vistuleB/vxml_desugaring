import blamedlines.{type Blame, Blame}
import codepoints.{type DelimiterPattern, delimiter_pattern_string_split}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/string
import vxml_parser.{type BlamedContent, type VXML, BlamedContent, T, V}

const ins = string.inspect

pub type DesugaringError {
  DesugaringError(blame: Blame, message: String)
  GetRootError(message: String)
}

pub fn on_error_on_ok(res: Result(a, b), f1: fn(b) -> c, f2: fn(a) -> c) -> c {
  case res {
    Error(e) -> f1(e)
    Ok(r) -> f2(r)
  }
}

pub fn announce_error(message: String) -> fn(e) -> Nil {
  fn(error) { io.println(message <> ": " <> ins(error)) }
}

pub fn on_error(
  res: Result(a, b),
  message: String,
  continue_with: fn(a) -> Nil,
) -> Nil {
  on_error_on_ok(res, announce_error(message), continue_with)
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

//**************************************************************
//* either-or functions
//**************************************************************

pub type EitherOr(a, b) {
  Either(a)
  Or(b)
}

pub const regex_prefix_to_make_unescaped = "(?<!\\\\)((?:\\\\\\\\)*)"

pub fn unescaped_suffix_regex(suffix: String) -> Regexp {
  let assert Ok(re) =
    regexp.compile(
      regex_prefix_to_make_unescaped <> suffix,
      regexp.Options(False, False),
    )
  re
}

pub type RegexWithIndexedGroup =
  #(Regexp, Int, Int)

pub fn string_split_into_list_either_content_or_blame_indexed_group_version(
  content: String,
  indexed_regex: RegexWithIndexedGroup,
) -> List(String) {
  let #(re, dropped_group, num_groups) = indexed_regex
  let splits = regexp.split(re, content)
  let num_matches: Int = { list.length(splits) - 1 } / { num_groups + 1 }
  let assert True =
    { num_matches * { num_groups + 1 } } + 1 == list.length(splits)
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
  string_split_into_list_either_content_or_blame_indexed_group_version(
    content,
    re,
  )
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

fn line_split_into_list_either_content_or_blame_delimiter_pattern_version(
  line: BlamedContent,
  pattern: DelimiterPattern,
) -> List(EitherOr(BlamedContent, Blame)) {
  let BlamedContent(blame, content) = line
  delimiter_pattern_string_split(content, pattern)
  |> list.map(fn(thing) { Either(BlamedContent(blame, thing)) })
  |> list.intersperse(Or(blame))
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

pub fn remove_ors_unwrap_eithers(ze_list: List(EitherOr(a, b))) -> List(a) {
  list.filter_map(ze_list, fn(either_or) {
    case either_or {
      Either(sth) -> Ok(sth)
      Or(_) -> Error(Nil)
    }
  })
}

pub fn regroup_eithers(
  ze_list: List(EitherOr(a, b)),
) -> List(EitherOr(List(a), b)) {
  regroup_eithers_accumulator([], [], ze_list)
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

pub fn either_or_function_combinant(
  fn1: fn(a) -> c,
  fn2: fn(b) -> c,
) -> fn(EitherOr(a, b)) -> c {
  fn(thing) {
    case thing {
      Either(a) -> fn1(a)
      Or(b) -> fn2(b)
    }
  }
}

pub fn either_or_mapper(
  ze_list: List(EitherOr(a, b)),
  fn1: fn(a) -> c,
  fn2: fn(b) -> c,
) -> List(c) {
  ze_list
  |> list.map(either_or_function_combinant(fn1, fn2))
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

pub fn regroup_ors(ze_list: List(EitherOr(a, b))) -> List(EitherOr(a, List(b))) {
  regroup_ors_accumulator([], [], ze_list)
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
//* regex-with-indexed-group splitting
//**************************************************************

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
  |> either_or_mapper(
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
  |> either_or_mapper(
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

fn replace_delimiter_pattern_by_tag_in_lines(
  lines: List(BlamedContent),
  pattern: DelimiterPattern,
  tag: String,
) -> List(VXML) {
  lines
  |> list.map(
    line_split_into_list_either_content_or_blame_delimiter_pattern_version(
      _,
      pattern,
    ),
  )
  |> list.flatten
  |> regroup_eithers
  |> either_or_mapper(
    fn(blamed_contents) {
      let assert [BlamedContent(blame, _), ..] = blamed_contents
      T(blame, blamed_contents)
    },
    fn(blame) { V(blame, tag, [], []) },
  )
}

fn replace_delimiter_pattern_by_tag_in_node(
  node: VXML,
  pattern: DelimiterPattern,
  tag: String,
) -> List(VXML) {
  case node {
    V(_, _, _, _) -> [node]
    T(_, lines) -> {
      replace_delimiter_pattern_by_tag_in_lines(lines, pattern, tag)
    }
  }
}

fn replace_delimiter_pattern_by_tag_in_nodes(
  nodes: List(VXML),
  pattern: DelimiterPattern,
  tag: String,
) -> List(VXML) {
  nodes
  |> list.map(replace_delimiter_pattern_by_tag_in_node(_, pattern, tag))
  |> list.flatten
}

fn replace_delimiter_patterns_by_tags_in_nodes(
  nodes: List(VXML),
  rules: List(#(DelimiterPattern, String)),
) -> List(VXML) {
  case rules {
    [] -> nodes
    [#(pattern, tag), ..rest] ->
      replace_delimiter_pattern_by_tag_in_nodes(nodes, pattern, tag)
      |> replace_delimiter_patterns_by_tags_in_nodes(rest)
  }
}

pub fn replace_delimiter_pattern_by_tag_param_transform(
  node: VXML,
  pattern: DelimiterPattern,
  tag: String,
) -> Result(List(VXML), DesugaringError) {
  Ok(replace_delimiter_pattern_by_tag_in_node(node, pattern, tag))
}

pub fn replace_delimiter_patterns_by_tags_param_transform(
  node: VXML,
  rules: List(#(DelimiterPattern, String)),
) -> Result(List(VXML), DesugaringError) {
  Ok(replace_delimiter_patterns_by_tags_in_nodes([node], rules))
}

//**************************************************************
//* blame etracting function                                   *
//**************************************************************

pub fn get_blame(vxml: VXML) -> Blame {
  case vxml {
    T(blame, _) -> blame
    V(blame, _, _, _) -> blame
  }
}

pub fn append_blame_comment(blame: Blame, comment: String) -> Blame {
  let Blame(filename, indent, comments) = blame
  Blame(filename, indent, [comment, ..comments])
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
    // case
    //   fancy_depth_first_node_to_nodes_desugar_one(
    //     root,
    //     [],
    //     [],
    //     [],
    //     [],
    //     transform,
    //   )
    // {
    //   Error(e) -> Error(e)
    //   Ok(vxmls) -> {
    //     let a: List(VXML) = vxmls
    //     case get_root(vxmls) {
    //       Ok(singleton) -> {
    //         let b: VXML = singleton
    //         Ok(singleton)
    //       }
    //       Error(message) -> Error(GetRootError(message))
    //     }
    //   }
    // }
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
  DoNotRecurse(a)
  Recurse(a)
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
    DoNotRecurse(new_node) -> Ok(new_node)
    Recurse(new_node) -> {
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

//*****************
//* pipeline type *
//*****************

pub type Desugarer =
  fn(VXML) -> Result(VXML, DesugaringError)

pub type DesugarerDescription {
  DesugarerDescription(
    function_name: String,
    extra: Option(String),
    general_description: String,
  )
}

pub type Pipe =
  #(DesugarerDescription, Desugarer)
