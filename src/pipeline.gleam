import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_indent.{insert_indent}
import desugarers/pair_bookends.{pair_bookends}
import desugarers/remove_empty_lines.{remove_empty_lines}
import desugarers/remove_vertical_chunks_with_no_text_child.{
  remove_vertical_chunks_with_no_text_child_desugarer,
}
import desugarers/remove_writerly_blurb_tags_around_text_nodes.{
  remove_writerly_blurb_tags_around_text_nodes_desugarer,
}
import desugarers/replace_double_dollars_by_tags.{replace_double_dollars_by_tags}
import desugarers/split_by_regexes.{split_by_regexes}
import desugarers/split_delimiters_chunks.{split_delimiters_chunks_desugarer}
import desugarers/split_vertical_chunks.{split_vertical_chunks}
import desugarers/wrap_element_children.{wrap_element_children_desugarer}
import desugarers/wrap_elements_by_blankline.{
  wrap_elements_by_blankline_desugarer,
}
import desugarers/wrap_math_with_no_break.{wrap_math_with_no_break}
import gleam/dict
import gleam/regex.{type Regex}
import infrastructure.{type Pipe} as infra

pub fn opening_central_display_italics_regex() -> Regex {
  let assert Ok(re) =
    regex.from_string("(?:^|\\s)(__)(?:(?:[a-zA-Z0-9])|(?:\\()|(?:\\[))")
  re
}

pub fn closing_central_display_italics_regex() -> Regex {
  let assert Ok(re) =
    regex.from_string("(?:(?:[a-zA-Z0-9])|(?:\\()|(?:\\[))(__)(?:$|\\s)")
  re
}

pub fn plain_double_underscore_regex() -> Regex {
  let assert Ok(re) = regex.from_string("__")
  re
}

pub fn opening_centerquote_regex() -> Regex {
  let assert Ok(re) = regex.from_string("_\\|")
  re
}

pub fn closing_centerquote_regex() -> Regex {
  let assert Ok(re) = regex.from_string("\\|_")
  re
}

pub fn pipeline_constructor() -> List(Pipe) {
  let unescaped_double_dollar_regex = infra.unescaped_suffix_regex("\\$\\$")
  let unescaped_simple_dollar_regex = infra.unescaped_suffix_regex("\\$")
  let unescaped_asterisk_regex = infra.unescaped_suffix_regex("\\*")
  let unescaped_underscore_regex = infra.unescaped_suffix_regex("_")
  let plain_double_underscore_regex = plain_double_underscore_regex()
  let opening_centerquote_regex = opening_centerquote_regex()
  let closing_centerquote_regex = closing_centerquote_regex()

  [
    remove_writerly_blurb_tags_around_text_nodes_desugarer(),
    //
    //
    // ***************************
    // START $$ -> MathBlock and $ -> Math
    split_by_regexes(#([#(unescaped_double_dollar_regex, "DoubleDollar")], [])),
    pair_bookends(#(["DoubleDollar"], ["DoubleDollar"], "MathBlock")),
    split_by_regexes(#([#(unescaped_simple_dollar_regex, "SimpleDollar")], [])),
    pair_bookends(#(["SimpleDollar"], ["SimpleDollar"], "Math")),
    fold_tags_into_text(dict.from_list([#("DoubleDollar", "$$")])),
    fold_tags_into_text(dict.from_list([#("SimpleDollar", "$")])),
    remove_empty_lines(),
    // END
    // ***************************
    //
    //
    // ***************************
    // START VerticalChunk creation
    wrap_elements_by_blankline_desugarer([
      "MathBlock", "Image", "Table", "Exercises", "Solution", "Example",
      "Section", "Exercise", "List", "Grid",
    ]),
    split_vertical_chunks(["MathBlock", "Math"]),
    remove_vertical_chunks_with_no_text_child_desugarer(),
    // END
    // ***************************
    //
    //
    // ***************************
    // START __ __ -> CentralItalicDisplay
    split_by_regexes(
      #([#(plain_double_underscore_regex, "DoubleUnderscore")], ["MathBlock"]),
    ),
    pair_bookends(#(
      ["DoubleUnderscore"],
      ["DoubleUnderscore"],
      "CentralItalicDisplay",
    )),
    fold_tags_into_text(dict.from_list([#("DoubleUnderscore", "__")])),
    remove_empty_lines(),
    // END
    // ***************************
    //
    //
    // ***************************
    // START _| |_ -> CenterDisplay
    split_by_regexes(
      #(
        [
          #(opening_centerquote_regex, "OpeningCenterQuote"),
          #(closing_centerquote_regex, "ClosingCenterQuote"),
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
    // END
    // ***************************
    //
    //
    // ***************************
    // START _ _ -> i
    split_by_regexes(
      #([#(unescaped_underscore_regex, "PlainUnderscore")], [
        "MathBlock", "Math",
      ]),
    ),
    pair_bookends(#(["PlainUnderscore"], ["PlainUnderscore"], "i")),
    fold_tags_into_text(dict.from_list([#("PlainUnderscore", "_")])),
    remove_empty_lines(),
    // END
    //
    //
    // ***************************
    // START * * -> i
    split_by_regexes(
      #([#(unescaped_asterisk_regex, "PlainAsterisk")], ["MathBlock", "Math"]),
    ),
    pair_bookends(#(["PlainAsterisk"], ["PlainAsterisk"], "b")),
    fold_tags_into_text(dict.from_list([#("PlainAsterisk", "*")])),
    remove_empty_lines(),
    // END
    // ***************************
    //
    //
    // ***************************
    // START misc
    wrap_math_with_no_break(),
    insert_indent(),
    wrap_element_children_desugarer(#(["List", "Grid"], "Item")),
    // END
  ]
}
