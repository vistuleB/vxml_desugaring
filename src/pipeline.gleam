import codepoints.{
  type DelimiterPattern, DelimiterPattern1, DelimiterPattern10, EndOfString, P1,
  P10, StartOfString,
}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_indent.{insert_indent}
import desugarers/pair_bookends.{pair_bookends}
import desugarers/remove_empty_lines.{remove_empty_lines}
import desugarers/remove_vertical_chunks_with_no_text_child.{
  remove_vertical_chunks_with_no_text_child,
}
import desugarers/split_by_delimiter_pattern.{split_by_delimiter_pattern}
import desugarers/split_vertical_chunks.{split_vertical_chunks}
import desugarers/unwrap_tags.{unwrap_tags}
import desugarers/wrap_element_children.{wrap_element_children_desugarer}
import desugarers/wrap_elements_by_blankline.{wrap_elements_by_blankline}
import desugarers/wrap_math_with_no_break.{wrap_math_with_no_break}
import gleam/dict
import infrastructure.{type Pipe}

pub fn pipeline_constructor() -> List(Pipe) {
  let double_dollar_delimiter_pattern: DelimiterPattern =
    P10(DelimiterPattern10(
      delimiter_chars: "$$" |> codepoints.as_utf_codepoints,
    ))

  let single_dollar_delimiter_pattern: DelimiterPattern =
    P10(DelimiterPattern10(delimiter_chars: "$" |> codepoints.as_utf_codepoints))

  let opening_double_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        [StartOfString],
        codepoints.space_string_chars(),
      ]),
      delimiter_chars: "__" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
      ]),
    ))

  let closing_double_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.closing_bracket_string_chars(),
      ]),
      delimiter_chars: "__" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
        [EndOfString],
      ]),
    ))

  let opening_central_quote_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        [StartOfString],
        codepoints.space_string_chars(),
      ]),
      delimiter_chars: "_|" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
      ]),
    ))

  let closing_central_quote_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.closing_bracket_string_chars(),
      ]),
      delimiter_chars: "|_" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
        [EndOfString],
      ]),
    ))

  let opening_single_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        [StartOfString],
        codepoints.space_string_chars(),
      ]),
      delimiter_chars: "_" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
      ]),
    ))

  let opening_or_closing_single_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.closing_bracket_string_chars(),
      ]),
      delimiter_chars: "_" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
      ]),
    ))

  let closing_single_underscore_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.closing_bracket_string_chars(),
      ]),
      delimiter_chars: "_" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.space_string_chars(),
        [EndOfString],
      ]),
    ))

  let opening_single_asterisk_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        [StartOfString],
        codepoints.space_string_chars(),
      ]),
      delimiter_chars: "*" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
      ]),
    ))

  let opening_or_closing_single_asterisk_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.closing_bracket_string_chars(),
      ]),
      delimiter_chars: "*" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.opening_bracket_string_chars(),
      ]),
    ))

  let closing_single_asterisk_delimiter_pattern =
    P1(DelimiterPattern1(
      match_one_of_before: codepoints.one_of([
        codepoints.alphanumeric_string_chars(),
        codepoints.closing_bracket_string_chars(),
      ]),
      delimiter_chars: "*" |> codepoints.as_utf_codepoints,
      match_one_of_after: codepoints.one_of([
        codepoints.space_string_chars(),
        [EndOfString],
      ]),
    ))

  [
    unwrap_tags(["WriterlyBurbNode"]),
    // ************************
    // $$ *********************
    // ************************
    split_by_delimiter_pattern(
      #([#(double_dollar_delimiter_pattern, "DoubleDollar")], []),
    ),
    pair_bookends(#(["DoubleDollar"], ["DoubleDollar"], "MathBlock")),
    fold_tags_into_text(dict.from_list([#("DoubleDollar", "$$")])),
    remove_empty_lines(),
    // ************************
    // VerticalChunk **********
    // ************************
    wrap_elements_by_blankline([
      "MathBlock", "Image", "Table", "Exercises", "Solution", "Example",
      "Section", "Exercise", "List", "Grid",
    ]),
    split_vertical_chunks(["MathBlock"]),
    remove_vertical_chunks_with_no_text_child(),
    // ************************
    // $ **********************
    // ************************
    split_by_delimiter_pattern(
      #([#(single_dollar_delimiter_pattern, "SingleDollar")], []),
    ),
    pair_bookends(#(["SingleDollar"], ["SingleDollar"], "Math")),
    fold_tags_into_text(dict.from_list([#("SingleDollar", "$")])),
    remove_empty_lines(),
    // ************************
    // __ *********************
    // ************************
    split_by_delimiter_pattern(
      #(
        [
          #(
            opening_double_underscore_delimiter_pattern,
            "OpeningDoubleUnderscore",
          ),
          #(
            closing_double_underscore_delimiter_pattern,
            "ClosingDoubleUnderscore",
          ),
        ],
        ["MathBlock", "Math"],
      ),
    ),
    pair_bookends(#(
      ["OpeningDoubleUnderscore"],
      ["ClosingDoubleUnderscore"],
      "CentralItalicDisplay",
    )),
    fold_tags_into_text(
      dict.from_list([
        #("OpeningDoubleUnderscore", "__"),
        #("ClosingDoubleUnderscore", "__"),
      ]),
    ),
    remove_empty_lines(),
    // // ************************
    // _| |_ ******************
    // ************************
    split_by_delimiter_pattern(
      #(
        [
          #(opening_central_quote_delimiter_pattern, "OpeningCenterQuote"),
          #(closing_central_quote_delimiter_pattern, "ClosingCenterQuote"),
        ],
        ["MathBlock"],
      ),
    ),
    pair_bookends(#(
      ["OpeningCenterQuote"],
      ["ClosingCenterQuote"],
      "CenterDisplay",
    )),
    fold_tags_into_text(
      dict.from_list([
        #("OpeningCenterQuote", "_|"),
        #("ClosingCenterQuote", "|_"),
      ]),
    ),
    remove_empty_lines(),
    // ************************
    // _ **********************
    // ************************
    split_by_delimiter_pattern(
      #(
        [
          #(opening_single_underscore_delimiter_pattern, "OpeningUnderscore"),
          #(
            opening_or_closing_single_underscore_delimiter_pattern,
            "OpeningOrClosingUnderscore",
          ),
          #(closing_single_underscore_delimiter_pattern, "ClosingUnderscore"),
        ],
        ["MathBlock", "Math"],
      ),
    ),
    pair_bookends(#(
      ["OpeningUnderscore", "OpeningOrClosingUnderscore"],
      ["ClosingUnderscore", "OpeningOrClosingUnderscore"],
      "i",
    )),
    fold_tags_into_text(
      dict.from_list([
        #("OpeningOrClosingUnderscore", "_"),
        #("OpeningUnderscore", "_"),
        #("ClosingUnderscore", "_"),
      ]),
    ),
    remove_empty_lines(),
    // ************************
    // * **********************
    // ************************
    split_by_delimiter_pattern(
      #(
        [
          #(opening_single_asterisk_delimiter_pattern, "OpeningAsterisk"),
          #(
            opening_or_closing_single_asterisk_delimiter_pattern,
            "OpeningOrClosingAsterisk",
          ),
          #(closing_single_asterisk_delimiter_pattern, "ClosingAsterisk"),
        ],
        ["MathBlock", "Math"],
      ),
    ),
    pair_bookends(#(
      ["OpeningAsterisk", "OpeningOrClosingAsterisk"],
      ["ClosingAsterisk", "OpeningOrClosingAsterisk"],
      "b",
    )),
    fold_tags_into_text(
      dict.from_list([
        #("OpeningOrClosingAsterisk", "*"),
        #("OpeningAsterisk", "*"),
        #("ClosingAsterisk", "*"),
      ]),
    ),
    remove_empty_lines(),
    // ************************
    // misc *******************
    // ************************
    wrap_math_with_no_break(),
    insert_indent(),
    wrap_element_children_desugarer(#(["List", "Grid"], "Item")),
  ]
}
