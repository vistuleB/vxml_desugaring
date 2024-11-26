import gleam/io
import gleam/list.{type ContinueOrStop, Continue, Stop}
import gleam/string

const ins = string.inspect

pub const as_utf_codepoints = string.to_utf_codepoints

fn as_string_chars(from: String) -> List(StringChar) {
  string.to_utf_codepoints(from) |> list.map(Codepoint)
}

pub type StringChar {
  Codepoint(UtfCodepoint)
  EndOfString
  StartOfString
}

pub type DelimiterPattern1 {
  DelimiterPattern1(
    match_one_of_before: List(StringChar),
    delimiter_chars: List(UtfCodepoint),
    match_one_of_after: List(StringChar),
  )
}

// *
// semantics of this one are not totally clear from
// just at type, but semantics are: match on substring
// 'delimiter_chars' if it is not preceded by an odd
// number of backslashes (i.e., if it is not escaped)
// *
pub type DelimiterPattern10 {
  DelimiterPattern10(delimiter_chars: List(UtfCodepoint))
}

// *
// same as DelimiterPattern10 but with a matching
// following character
// *
pub type DelimiterPattern5 {
  DelimiterPattern5(
    delimiter_chars: List(UtfCodepoint),
    match_one_of_after: List(StringChar),
  )
}

pub type DelimiterPattern {
  P1(DelimiterPattern1)
  P5(DelimiterPattern5)
  P10(DelimiterPattern10)
}

pub fn alphanumeric_string_chars() -> List(StringChar) {
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  |> as_string_chars
}

pub fn space_string_chars() -> List(StringChar) {
  " " |> as_string_chars
}

pub fn opening_bracket_string_chars() -> List(StringChar) {
  "({[" |> as_string_chars
}

pub fn closing_bracket_string_chars() -> List(StringChar) {
  ")}]" |> as_string_chars
}

pub fn backslash_string_chars() -> List(StringChar) {
  "\\" |> as_string_chars
}

pub const one_of = list.flatten

fn while_not_stop(
  initial_state initial_state: a,
  map map: fn(a) -> ContinueOrStop(a),
) -> a {
  case map(initial_state) {
    Stop(new_state) -> new_state
    Continue(new_state) -> while_not_stop(new_state, map)
  }
}

type PrefixMatchLastCharVersionState {
  PrefixMatchLastCharVersionState(
    last_char_before_input: StringChar,
    remaining_pattern_chars: List(UtfCodepoint),
    remaining_input_chars: List(UtfCodepoint),
  )
}

fn prefix_match_last_char_version_continue_or_stop(
  state: PrefixMatchLastCharVersionState,
) -> ContinueOrStop(PrefixMatchLastCharVersionState) {
  let PrefixMatchLastCharVersionState(
    _,
    remaining_pattern_chars,
    remaining_input_chars,
  ) = state
  case remaining_pattern_chars, remaining_input_chars {
    [], _ -> Stop(state)
    _, [] -> Stop(state)
    [first_pattern, ..rest_pattern], [first_input, ..rest_input] ->
      case first_pattern == first_input {
        False -> Stop(state)
        True ->
          prefix_match_last_char_version_continue_or_stop(
            PrefixMatchLastCharVersionState(
              Codepoint(first_input),
              rest_pattern,
              rest_input,
            ),
          )
      }
  }
}

fn prefix_match_last_char_version(
  initial_last_char_before_input: StringChar,
  pattern: List(UtfCodepoint),
  input: List(UtfCodepoint),
) -> #(Bool, StringChar, List(UtfCodepoint)) {
  let final_state =
    while_not_stop(
      PrefixMatchLastCharVersionState(
        initial_last_char_before_input,
        pattern,
        input,
      ),
      prefix_match_last_char_version_continue_or_stop,
    )
  case final_state {
    PrefixMatchLastCharVersionState(last_char, [], remaining_input) -> #(
      True,
      last_char,
      remaining_input,
    )
    PrefixMatchLastCharVersionState(last_char, _, remaining_input) -> #(
      False,
      last_char,
      remaining_input,
    )
  }
}

type PrefixMatchUtfBackslashCounterVersionState {
  PrefixMatchUtfBackslashCounterVersionState(
    num_backslashes_before_input: Int,
    remaining_pattern_chars: List(UtfCodepoint),
    remaining_input_chars: List(UtfCodepoint),
  )
}

fn prefix_match_backslash_counter_version_continue_or_stop(
  state: PrefixMatchUtfBackslashCounterVersionState,
) -> ContinueOrStop(PrefixMatchUtfBackslashCounterVersionState) {
  let PrefixMatchUtfBackslashCounterVersionState(
    num_backslashes_before_input,
    remaining_pattern_chars,
    remaining_input_chars,
  ) = state
  case remaining_pattern_chars, remaining_input_chars {
    [], _ -> Stop(state)
    _, [] -> Stop(state)
    [first_pattern, ..rest_pattern], [first_input, ..rest_input] ->
      case first_pattern == first_input {
        False -> Stop(state)
        True -> {
          let new_num_backslashes = case is_backlash(first_input) {
            True -> num_backslashes_before_input + 1
            False -> 0
          }
          let new_state =
            PrefixMatchUtfBackslashCounterVersionState(
              new_num_backslashes,
              rest_pattern,
              rest_input,
            )
          prefix_match_backslash_counter_version_continue_or_stop(new_state)
        }
      }
  }
}

fn prefix_match_backslash_counter_version(
  num_backslashes_before_in: Int,
  pattern: List(UtfCodepoint),
  input: List(UtfCodepoint),
) -> #(Bool, Int, List(UtfCodepoint)) {
  let final_state =
    while_not_stop(
      PrefixMatchUtfBackslashCounterVersionState(
        num_backslashes_before_in,
        pattern,
        input,
      ),
      prefix_match_backslash_counter_version_continue_or_stop,
    )
  case final_state {
    PrefixMatchUtfBackslashCounterVersionState(
      num_backslashes,
      [],
      remaining_input,
    ) -> #(True, num_backslashes, remaining_input)
    PrefixMatchUtfBackslashCounterVersionState(
      num_backslashes,
      _,
      remaining_input,
    ) -> #(False, num_backslashes, remaining_input)
  }
}

fn prefix_match_one_string_char_version(
  in: List(UtfCodepoint),
  one_of: List(StringChar),
) -> Bool {
  case in {
    [] -> list.contains(one_of, EndOfString)
    [first, ..] -> list.contains(one_of, Codepoint(first))
  }
}

fn delimiter_pattern_1_vanilla_split_matcher_parameterized(
  last_char_before_remaining_chars: StringChar,
  remaining_chars: List(UtfCodepoint),
  pattern: DelimiterPattern1,
) -> #(Bool, List(UtfCodepoint), StringChar, List(UtfCodepoint)) {
  let DelimiterPattern1(
    match_one_of_before,
    delimiter_chars,
    match_one_of_after,
  ) = pattern
  let assert [first_char, ..rest] = remaining_chars
  let failure_return_value = #(False, [first_char], Codepoint(first_char), rest)
  case list.contains(match_one_of_before, last_char_before_remaining_chars) {
    False -> failure_return_value
    True ->
      case
        prefix_match_last_char_version(
          last_char_before_remaining_chars,
          delimiter_chars,
          remaining_chars,
        )
      {
        #(False, _, _) -> failure_return_value
        #(True, new_last_char, after_delimiter_chars) ->
          case
            prefix_match_one_string_char_version(
              after_delimiter_chars,
              match_one_of_after,
            )
          {
            False -> failure_return_value
            True -> #(
              True,
              delimiter_chars |> list.reverse,
              new_last_char,
              after_delimiter_chars,
            )
          }
      }
  }
}

fn delimiter_pattern_5_vanilla_split_matcher_parameterized(
  num_preceding_backslashes: Int,
  remaining_chars: List(UtfCodepoint),
  pattern: DelimiterPattern5,
) -> #(Bool, List(UtfCodepoint), Int, List(UtfCodepoint)) {
  let DelimiterPattern5(delimiter_chars, match_one_of_after) = pattern
  let assert [first_char, ..rest] = remaining_chars
  let new_num_backslashes_after_first = case is_backlash(first_char) {
    True -> num_preceding_backslashes + 1
    False -> 0
  }
  let failure_return_value = #(
    False,
    [first_char],
    new_num_backslashes_after_first,
    rest,
  )
  case num_preceding_backslashes % 2 == 0 {
    False -> failure_return_value
    True ->
      case
        prefix_match_backslash_counter_version(
          num_preceding_backslashes,
          delimiter_chars,
          remaining_chars,
        )
      {
        #(False, _, _) -> failure_return_value
        #(
          True,
          new_num_backslashes_after_delimiter_chars,
          after_delimiter_chars,
        ) ->
          case
            prefix_match_one_string_char_version(
              after_delimiter_chars,
              match_one_of_after,
            )
          {
            False -> failure_return_value
            True -> #(
              True,
              delimiter_chars |> list.reverse,
              new_num_backslashes_after_delimiter_chars,
              after_delimiter_chars,
            )
          }
      }
  }
}

fn delimiter_pattern_10_vanilla_split_matcher_parameterized(
  num_preceding_backslashes: Int,
  remaining_chars: List(UtfCodepoint),
  pattern: DelimiterPattern10,
) -> #(Bool, List(UtfCodepoint), Int, List(UtfCodepoint)) {
  let DelimiterPattern10(delimiter_chars) = pattern
  let assert [first_char, ..rest] = remaining_chars
  let new_num_backslashes_after_first = case is_backlash(first_char) {
    True -> num_preceding_backslashes + 1
    False -> 0
  }
  let failure_return_value = #(
    False,
    [first_char],
    new_num_backslashes_after_first,
    rest,
  )
  case num_preceding_backslashes % 2 == 0 {
    False -> failure_return_value
    True ->
      case
        prefix_match_backslash_counter_version(
          num_preceding_backslashes,
          delimiter_chars,
          remaining_chars,
        )
      {
        #(False, _, _) -> failure_return_value
        #(
          True,
          new_num_backslashes_after_delimiter_chars,
          after_delimiter_chars,
        ) -> #(
          True,
          delimiter_chars |> list.reverse,
          new_num_backslashes_after_delimiter_chars,
          after_delimiter_chars,
        )
      }
  }
}

fn delimiter_pattern_1_vanilla_splitter_constructor(
  pattern: DelimiterPattern1,
) -> VanillaSplitter(StringChar) {
  VanillaSplitter(
    initial_pre_input_info: StartOfString,
    matcher: fn(last_char_before_remaining_chars, remaining_chars) {
      delimiter_pattern_1_vanilla_split_matcher_parameterized(
        last_char_before_remaining_chars,
        remaining_chars,
        pattern,
      )
    },
  )
}

fn delimiter_pattern_5_vanilla_splitter_constructor(
  pattern: DelimiterPattern5,
) -> VanillaSplitter(Int) {
  VanillaSplitter(
    initial_pre_input_info: 0,
    matcher: fn(num_backslashes_before_remaining_chars, remaining_chars) {
      delimiter_pattern_5_vanilla_split_matcher_parameterized(
        num_backslashes_before_remaining_chars,
        remaining_chars,
        pattern,
      )
    },
  )
}

fn delimiter_pattern_10_vanilla_splitter_constructor(
  pattern: DelimiterPattern10,
) -> VanillaSplitter(Int) {
  VanillaSplitter(
    initial_pre_input_info: 0,
    matcher: fn(num_backslashes_before_remaining_chars, remaining_chars) {
      delimiter_pattern_10_vanilla_split_matcher_parameterized(
        num_backslashes_before_remaining_chars,
        remaining_chars,
        pattern,
      )
    },
  )
}

type VanillaSplitMatcher(pre_input_info) =
  fn(pre_input_info, List(UtfCodepoint)) ->
    #(Bool, List(UtfCodepoint), pre_input_info, List(UtfCodepoint))

type VanillaSplitter(pre_input_info) {
  VanillaSplitter(
    initial_pre_input_info: pre_input_info,
    matcher: VanillaSplitMatcher(pre_input_info),
  )
}

type VanillaSplitterContinueOrStopState(pre_input_info) {
  VanillaSplitterContinueOrStopState(
    previous_splits: List(List(UtfCodepoint)),
    chars_since_last_split: List(UtfCodepoint),
    pre_input_info: pre_input_info,
    remaining_input: List(UtfCodepoint),
  )
}

fn vanilla_splitter_continue_or_stop(
  state: VanillaSplitterContinueOrStopState(a),
  matcher: VanillaSplitMatcher(a),
) -> ContinueOrStop(VanillaSplitterContinueOrStopState(a)) {
  let VanillaSplitterContinueOrStopState(
    previous_splits,
    chars_since_last_split,
    pre_input_info,
    remaining_input,
  ) = state
  case remaining_input {
    [] -> Stop(state)
    _ ->
      case matcher(pre_input_info, remaining_input) {
        #(False, chars_eaten, new_pre_input_info, new_remaining_input) -> {
          Continue(VanillaSplitterContinueOrStopState(
            previous_splits,
            list.flatten([chars_eaten, chars_since_last_split]),
            new_pre_input_info,
            new_remaining_input,
          ))
        }
        #(True, _, new_pre_input_info, new_remaining_input) ->
          Continue(VanillaSplitterContinueOrStopState(
            [chars_since_last_split |> list.reverse, ..previous_splits],
            [],
            new_pre_input_info,
            new_remaining_input,
          ))
      }
  }
}

fn utf_split_for_vanilla_splitter(
  input: List(UtfCodepoint),
  splitter: VanillaSplitter(a),
) -> List(List(UtfCodepoint)) {
  let VanillaSplitter(initial_pre_input_info, matcher) = splitter
  let initial_vanilla_splitter_continue_or_stop_state =
    VanillaSplitterContinueOrStopState(
      previous_splits: [],
      chars_since_last_split: [],
      pre_input_info: initial_pre_input_info,
      remaining_input: input,
    )
  let final_state =
    while_not_stop(
      initial_vanilla_splitter_continue_or_stop_state,
      vanilla_splitter_continue_or_stop(_, matcher),
    )
  let assert VanillaSplitterContinueOrStopState(
    final_previous_splits,
    final_chars_since_last_split,
    _,
    [],
  ) = final_state
  [final_chars_since_last_split |> list.reverse, ..final_previous_splits]
  |> list.reverse
}

fn is_backlash(pt: UtfCodepoint) -> Bool {
  string.utf_codepoint_to_int(pt) == 92
}

fn string_split_for_vanilla_splitter(
  content: String,
  splitter: VanillaSplitter(a),
) -> List(String) {
  content
  |> as_utf_codepoints
  |> utf_split_for_vanilla_splitter(splitter)
  |> list.map(string.from_utf_codepoints)
}

pub fn delimiter_pattern_string_split(
  content: String,
  pattern: DelimiterPattern,
) -> List(String) {
  case pattern {
    P1(pattern1) ->
      string_split_for_vanilla_splitter(
        content,
        delimiter_pattern_1_vanilla_splitter_constructor(pattern1),
      )
    P5(pattern5) ->
      string_split_for_vanilla_splitter(
        content,
        delimiter_pattern_5_vanilla_splitter_constructor(pattern5),
      )
    P10(pattern10) ->
      string_split_for_vanilla_splitter(
        content,
        delimiter_pattern_10_vanilla_splitter_constructor(pattern10),
      )
  }
}

pub fn tests() -> Nil {
  let pattern1 =
    DelimiterPattern1(
      match_one_of_before: " " |> as_string_chars,
      delimiter_chars: "aa" |> as_utf_codepoints,
      match_one_of_after: "(" |> as_string_chars,
    )

  let double_dollar_delimiter_pattern =
    P10(DelimiterPattern10(delimiter_chars: "$$" |> as_utf_codepoints))

  let assert [space_utf_codepoint] = string.to_utf_codepoints(" ")
  let assert [opening_parenthesis_utf_codepoint] = string.to_utf_codepoints("(")
  let assert [underscore_utf_codepoint] = string.to_utf_codepoints("_")
  let alphanumeric_utf_codepoints =
    string.to_utf_codepoints(
      "abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVXYZ0123456789",
    )
  let brackets_utf_codepoints = string.to_utf_codepoints("()[]{}")

  let opening_double_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: one_of([[StartOfString], space_string_chars()]),
      delimiter_chars: "__" |> as_utf_codepoints,
      match_one_of_after: one_of([
        alphanumeric_string_chars(),
        opening_bracket_string_chars(),
      ]),
    ))

  let closing_double_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: one_of([
        alphanumeric_string_chars(),
        closing_bracket_string_chars(),
      ]),
      delimiter_chars: "__" |> as_utf_codepoints,
      match_one_of_after: one_of([
        [EndOfString],
        alphanumeric_string_chars(),
        opening_bracket_string_chars(),
      ]),
    ))

  io.println(
    ins(delimiter_pattern_string_split(
      "__\\\\$$aa__",
      double_dollar_delimiter_pattern,
    )),
  )
  // io.println(
  //   ins(delimiter_pattern_string_split(
  //     "hello aa$$hm \\$$hm \\\\$$",
  //     P10(pattern10),
  //   )),
  // )
  Nil
}
