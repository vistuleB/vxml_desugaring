import codepoints.{type DelimiterPattern}
import gleam/option.{Some}
import gleam/string
import infrastructure.{
  type Desugarer, type NodeToNodesFancyTransform, type Pipe,
  DesugarerDescription,
} as infra

const ins = string.inspect

type Extras =
  #(List(#(DelimiterPattern, String)), List(String))

fn transform_factory(extras: Extras) -> NodeToNodesFancyTransform {
  let #(patterns_and_tags, forbidden_parents) = extras
  infra.replace_delimiter_patterns_by_tags_param_transform(_, patterns_and_tags)
  |> infra.prevent_node_to_nodes_transform_inside(forbidden_parents)
}

fn desugarer_factory(extras: Extras) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extras))
}

pub fn split_by_delimiter_pattern(extras: Extras) -> Pipe {
  #(
    DesugarerDescription(
      "split_by_delimiter_patterns",
      Some(ins(extras)),
      "...",
    ),
    desugarer_factory(extras),
  )
}
//**********************
//old patterns for reference:
//**********************

// let double_dollar_delimiter_pattern: DelimiterPattern =
//   P10(DelimiterPattern10(
//     delimiter_chars: "$$" |> codepoints.as_utf_codepoints,
//   ))

// let single_dollar_delimiter_pattern: DelimiterPattern =
//   P10(DelimiterPattern10(delimiter_chars: "$" |> codepoints.as_utf_codepoints))

// let opening_double_underscore_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       [StartOfString],
//       codepoints.space_string_chars(),
//     ]),
//     delimiter_chars: "__" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//     ]),
//   ))

// let closing_double_underscore_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.closing_bracket_string_chars(),
//     ]),
//     delimiter_chars: "__" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//       [EndOfString],
//     ]),
//   ))

// let opening_central_quote_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       [StartOfString],
//       codepoints.space_string_chars(),
//     ]),
//     delimiter_chars: "_|" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//     ]),
//   ))

// let closing_central_quote_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.closing_bracket_string_chars(),
//     ]),
//     delimiter_chars: "|_" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//       [EndOfString],
//     ]),
//   ))

// let opening_single_underscore_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       [StartOfString],
//       codepoints.space_string_chars(),
//     ]),
//     delimiter_chars: "_" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//     ]),
//   ))

// let opening_or_closing_single_underscore_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.closing_bracket_string_chars(),
//     ]),
//     delimiter_chars: "_" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//     ]),
//   ))

// let closing_single_underscore_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.closing_bracket_string_chars(),
//     ]),
//     delimiter_chars: "_" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.space_string_chars(),
//       [EndOfString],
//     ]),
//   ))

// let opening_single_asterisk_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       [StartOfString],
//       codepoints.space_string_chars(),
//     ]),
//     delimiter_chars: "*" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//     ]),
//   ))

// let opening_or_closing_single_asterisk_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.closing_bracket_string_chars(),
//     ]),
//     delimiter_chars: "*" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.opening_bracket_string_chars(),
//     ]),
//   ))

// let closing_single_asterisk_delimiter_pattern =
//   P1(DelimiterPattern1(
//     match_one_of_before: codepoints.one_of([
//       codepoints.alphanumeric_string_chars(),
//       codepoints.closing_bracket_string_chars(),
//     ]),
//     delimiter_chars: "*" |> codepoints.as_utf_codepoints,
//     match_one_of_after: codepoints.one_of([
//       codepoints.space_string_chars(),
//       [EndOfString],
//     ]),
//   ))
