import gleam/io
import gleam/list
import gleam/string

const ins = string.inspect

type StringChar {
  Codepoint(UtfCodepoint)
  EOS
  SOS
}

type DelimiterPattern1 {
  DelimiterPattern1(
    match_one_of_before: List(StringChar),
    delimiter_chars: List(UtfCodepoint),
    match_one_of_after: List(StringChar),
  )
}

fn prefix_match_last_char_version(
  pattern: List(UtfCodepoint),
  last_char_before_in: StringChar,
  in: List(UtfCodepoint),
) -> #(Bool, StringChar, List(UtfCodepoint)) {
  case pattern {
    [] -> #(True, last_char_before_in, in)
    [pattern_first, ..pattern_rest] -> {
      case in {
        [] -> #(False, last_char_before_in, in)
        [in_first, ..in_rest] ->
          case in_first == pattern_first {
            False -> #(False, last_char_before_in, in)
            True ->
              prefix_match_last_char_version(
                pattern_rest,
                Codepoint(in_first),
                in_rest,
              )
          }
      }
    }
  }
}

fn prefix_match_utf_backslash_counter_version(
  pattern: List(UtfCodepoint),
  num_backslashes_before_in: Int,
  in: List(UtfCodepoint),
) -> #(Bool, Int, List(UtfCodepoint)) {
  case pattern {
    [] -> #(True, num_backslashes_before_in, in)
    [pattern_first, ..pattern_rest] -> {
      case in {
        [] -> #(False, num_backslashes_before_in, in)
        [in_first, ..in_rest] ->
          case in_first == pattern_first {
            False -> #(False, num_backslashes_before_in, in)
            True -> {
              let new_num_backslashes = case is_backlash(in_first) {
                True -> num_backslashes_before_in + 1
                False -> 0
              }
              prefix_match_utf_backslash_counter_version(
                pattern_rest,
                new_num_backslashes,
                in_rest,
              )
            }
          }
      }
    }
  }
}

fn prefix_match_one_string_version(
  in: List(UtfCodepoint),
  one_of: List(StringChar),
) -> Bool {
  case in {
    [] -> list.contains(one_of, EOS)
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
        prefix_match_last_char_version(
          delimiter_chars,
          last_char_before_remaining_chars,
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
  pattern: DelimiterPattern1,
  chars: List(UtfCodepoint),
) -> List(List(UtfCodepoint)) {
  utf_split_for_delimiter_pattern_1_acc(pattern, [], [], SOS, chars)
}

type DelimiterPattern10 {
  DelimiterPattern10(delimiter_chars: List(UtfCodepoint))
}

fn is_backlash(pt: UtfCodepoint) -> Bool {
  let assert [backslash] = string.to_utf_codepoints("\\")
  let assert True = string.utf_codepoint_to_int(backslash) == 92
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
          delimiter_chars,
          num_preceding_backslashes,
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
  pattern: DelimiterPattern10,
  chars: List(UtfCodepoint),
) -> List(List(UtfCodepoint)) {
  utf_split_for_delimiter_pattern_10_acc(pattern, [], [], 0, chars)
}

const as_utf_codepoints = string.to_utf_codepoints

fn as_string_chars(from: String) -> List(StringChar) {
  string.to_utf_codepoints(from) |> list.map(Codepoint)
}

pub fn tests() -> Nil {
  io.println(ins(string.to_utf_codepoints("\\")))
  let assert Ok(b) = string.utf_codepoint(50)
  io.println(ins(b))
  io.println(ins(Codepoint(b)))
  string.from_utf_codepoints([])

  let pattern1 =
    DelimiterPattern1(
      match_one_of_before: " " |> as_string_chars,
      delimiter_chars: "aa" |> as_utf_codepoints,
      match_one_of_after: "(" |> as_string_chars,
    )

  let pattern10 = DelimiterPattern10(delimiter_chars: "$$" |> as_utf_codepoints)

  io.println(ins(
    utf_split_for_delimiter_pattern_1(
      pattern1,
      "hello aa(hm hm" |> as_utf_codepoints,
    )
    |> list.map(string.from_utf_codepoints),
  ))

  io.println(ins(
    utf_split_for_delimiter_pattern_10(
      pattern10,
      "hello aa$$hm \\$$hm \\\\$$" |> as_utf_codepoints,
    )
    |> list.map(string.from_utf_codepoints),
  ))
}
