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

pub type DelimiterPattern {
  P1(DelimiterPattern1)
  P10(DelimiterPattern10)
}

pub fn alphanumeric_string_chars() -> List(StringChar) {
  "abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVXYZ0123456789"
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

fn prefix_match_utf_backslash_counter_version_continue_or_stop(
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
          prefix_match_utf_backslash_counter_version_continue_or_stop(new_state)
        }
      }
  }
}

fn prefix_match_utf_backslash_counter_version(
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
      prefix_match_utf_backslash_counter_version_continue_or_stop,
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

fn prefix_match_one_string_version(
  in: List(UtfCodepoint),
  one_of: List(StringChar),
) -> Bool {
  case in {
    [] -> list.contains(one_of, EndOfString)
    [first, ..] -> list.contains(one_of, Codepoint(first))
  }
}

fn utf_split_for_delimiter_pattern_1_acc(
  pattern: DelimiterPattern1,
  previous_splits: List(List(UtfCodepoint)),
  chars_since_last_split: List(UtfCodepoint),
  last_char_before_remaining_chars: StringChar,
  remaining_chars: List(UtfCodepoint),
) -> List(List(UtfCodepoint)) {
  let DelimiterPattern1(before_matchers, delimiter_chars, after_matchers) =
    pattern
  case list.contains(before_matchers, last_char_before_remaining_chars) {
    False ->
      case remaining_chars {
        [] -> {
          let last_split = chars_since_last_split |> list.reverse
          [last_split, ..previous_splits] |> list.reverse
        }
        [first, ..rest] -> {
          utf_split_for_delimiter_pattern_1_acc(
            pattern,
            previous_splits,
            [first, ..chars_since_last_split],
            Codepoint(first),
            rest,
          )
        }
      }
    True ->
      case
        io.debug(prefix_match_last_char_version(
          io.debug(last_char_before_remaining_chars),
          delimiter_chars,
          remaining_chars,
        ))
      {
        #(False, _, _) -> {
          case remaining_chars {
            [] -> {
              let last_split = chars_since_last_split |> list.reverse
              [last_split, ..previous_splits] |> list.reverse
            }
            [first, ..rest] -> {
              utf_split_for_delimiter_pattern_1_acc(
                pattern,
                previous_splits,
                [first, ..chars_since_last_split],
                Codepoint(first),
                rest,
              )
            }
          }
        }
        #(True, new_last_char, after_delimiter_chars) -> {
          case
            prefix_match_one_string_version(
              after_delimiter_chars,
              after_matchers,
            )
          {
            False -> {
              case remaining_chars {
                [] -> {
                  let last_split = chars_since_last_split |> list.reverse
                  [last_split, ..previous_splits] |> list.reverse
                }
                [first, ..rest] -> {
                  utf_split_for_delimiter_pattern_1_acc(
                    pattern,
                    previous_splits,
                    [first, ..chars_since_last_split],
                    Codepoint(first),
                    rest,
                  )
                }
              }
            }
            True -> {
              let new_split = chars_since_last_split |> list.reverse
              let new_previous_splits = [new_split, ..previous_splits]
              utf_split_for_delimiter_pattern_1_acc(
                pattern,
                new_previous_splits,
                [],
                new_last_char,
                after_delimiter_chars,
              )
            }
          }
        }
      }
  }
}

fn utf_split_for_delimiter_pattern_1(
  chars: List(UtfCodepoint),
  pattern: DelimiterPattern1,
) -> List(List(UtfCodepoint)) {
  utf_split_for_delimiter_pattern_1_acc(pattern, [], [], StartOfString, chars)
}

fn is_backlash(pt: UtfCodepoint) -> Bool {
  string.utf_codepoint_to_int(pt) == 92
}

fn utf_split_for_delimiter_pattern_10_acc(
  pattern: DelimiterPattern10,
  previous_splits: List(List(UtfCodepoint)),
  chars_since_last_split: List(UtfCodepoint),
  num_preceding_backslashes: Int,
  remaining_chars: List(UtfCodepoint),
) -> List(List(UtfCodepoint)) {
  let DelimiterPattern10(delimiter_chars) = pattern
  case num_preceding_backslashes % 2 == 0 {
    False -> {
      case remaining_chars {
        [] -> {
          let last_split = chars_since_last_split |> list.reverse
          [last_split, ..previous_splits] |> list.reverse
        }
        [first, ..rest] -> {
          let new_num_backslashes = case is_backlash(first) {
            False -> 0
            True -> num_preceding_backslashes + 1
          }
          utf_split_for_delimiter_pattern_10_acc(
            pattern,
            previous_splits,
            [first, ..chars_since_last_split],
            new_num_backslashes,
            rest,
          )
        }
      }
    }
    True -> {
      case
        prefix_match_utf_backslash_counter_version(
          num_preceding_backslashes,
          delimiter_chars,
          remaining_chars,
        )
      {
        #(False, _, _) -> {
          case remaining_chars {
            [] -> {
              let last_split = chars_since_last_split |> list.reverse
              [last_split, ..previous_splits] |> list.reverse
            }
            [first, ..rest] -> {
              let new_num_backslashes = case is_backlash(first) {
                False -> 0
                True -> num_preceding_backslashes + 1
              }
              utf_split_for_delimiter_pattern_10_acc(
                pattern,
                previous_splits,
                [first, ..chars_since_last_split],
                new_num_backslashes,
                rest,
              )
            }
          }
        }
        #(True, new_num_backslashes, new_remaining_chars) -> {
          let new_split = chars_since_last_split |> list.reverse
          let new_previous_splits = [new_split, ..previous_splits]
          utf_split_for_delimiter_pattern_10_acc(
            pattern,
            new_previous_splits,
            [],
            new_num_backslashes,
            new_remaining_chars,
          )
        }
      }
    }
  }
}

fn utf_split_for_delimiter_pattern_10(
  chars: List(UtfCodepoint),
  pattern: DelimiterPattern10,
) -> List(List(UtfCodepoint)) {
  utf_split_for_delimiter_pattern_10_acc(pattern, [], [], 0, chars)
}

pub fn string_split_for_delimiter_pattern_1(
  content: String,
  pattern: DelimiterPattern1,
) -> List(String) {
  content
  |> as_utf_codepoints
  |> utf_split_for_delimiter_pattern_1(pattern)
  |> list.map(string.from_utf_codepoints)
}

pub fn string_split_for_delimiter_pattern_10(
  content: String,
  pattern: DelimiterPattern10,
) -> List(String) {
  content
  |> as_utf_codepoints
  |> utf_split_for_delimiter_pattern_10(pattern)
  |> list.map(string.from_utf_codepoints)
}

pub fn delimiter_pattern_string_split(
  content: String,
  pattern: DelimiterPattern,
) -> List(String) {
  case pattern {
    P1(pattern1) -> string_split_for_delimiter_pattern_1(content, pattern1)
    P10(pattern10) -> string_split_for_delimiter_pattern_10(content, pattern10)
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
