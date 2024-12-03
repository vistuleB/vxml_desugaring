import desugarers/add_counter_attributes.{add_counter_attributes}
import desugarers/add_exercise_labels.{add_exercise_labels}
import desugarers/add_title_counters_and_titles.{add_title_counters_and_titles}
import desugarers/concatenate_text_nodes.{concatenate_text_nodes}
import desugarers/convert_int_attributes_to_float.{
  convert_int_attributes_to_float,
}
import desugarers/counter.{counter_desugarer}
import desugarers/counter_handles.{counter_handles_desugarer}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/free_children.{free_children}
import desugarers/insert_indent.{insert_indent}
import desugarers/pair_bookends.{pair_bookends}
import desugarers/remove_empty_lines.{remove_empty_lines}
import desugarers/remove_vertical_chunks_with_no_text_child.{
  remove_vertical_chunks_with_no_text_child,
}
import desugarers/split_by_indexed_regexes.{split_by_indexed_regexes}
import desugarers/split_vertical_chunks.{split_vertical_chunks}
import desugarers/unwrap_tags.{unwrap_tags}
import desugarers/wrap_element_children.{wrap_element_children_desugarer}
import desugarers/wrap_elements_by_blankline.{wrap_elements_by_blankline}
import desugarers/wrap_math_with_no_break.{wrap_math_with_no_break}
import gleam/dict
import gleam/regex
import infrastructure.{type Pipe} as infra

pub fn pipeline_constructor() -> List(Pipe) {
  let double_dollar_indexed_regex = #(
    infra.unescaped_suffix_regex("(\\$\\$)"),
    1,
    2,
  )

  let single_dollar_indexed_regex = #(
    infra.unescaped_suffix_regex("(\\$)"),
    1,
    2,
  )

  let opening_double_underscore_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(^|\\s)(__)(\\w|[\\*\\(\\[{“])")
      re
    },
    1,
    3,
  )

  let closing_double_underscore_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(\\w|[\\*\\)\\]}”~])(__)($|\\s)")
      re
    },
    1,
    3,
  )

  let opening_central_quote_indexed_regex = #(
    {
      let assert Ok(re) =
        regex.from_string("(^|\\s)(_\\|)(\\w|[_\\*\\(\\[{“])")
      re
    },
    1,
    3,
  )

  let closing_central_quote_indexed_regex = #(
    {
      let assert Ok(re) =
        regex.from_string("(\\w|[_\\*\\)\\]}”~])(\\|_)($|\\s)")
      re
    },
    1,
    3,
  )

  let opening_single_underscore_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(^|\\s)(_)(\\w|[\\*\\(\\[{])")
      re
    },
    1,
    3,
  )

  let opening_or_closing_single_underscore_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(\\w|[\\(\\[{])(_)(\\w|[\\)\\]}])")
      re
    },
    1,
    3,
  )

  let opening_or_closing_single_underscore_indexed_regex_with_asterisks = #(
    {
      let assert Ok(re) =
        regex.from_string("(\\w|[\\.\\*\\(\\[{])(_)(\\w|[\\*\\)\\]}])")
      re
    },
    1,
    3,
  )

  let closing_single_underscore_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(\\w|[\\.\\*\\(\\[{])(_)(\\s|$)")
      re
    },
    1,
    3,
  )

  let opening_single_asterisk_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(^|\\s)(\\*)(\\w|[_\\(\\[{])")
      re
    },
    1,
    3,
  )

  let opening_or_closing_single_asterisk_indexed_regex = #(
    {
      let assert Ok(re) =
        regex.from_string("(\\w|[\\._\\(\\[{])(\\*)(\\w|[_\\)\\]}])")
      re
    },
    1,
    3,
  )

  let closing_single_asterisk_indexed_regex = #(
    {
      let assert Ok(re) = regex.from_string("(\\w|[\\._\\(\\[{])(\\*)(\\s|$)")
      re
    },
    1,
    3,
  )

  [
    unwrap_tags(["WriterlyBlurb"]),
    convert_int_attributes_to_float([#("", "line"), #("", "padding_left")]),
    // ************************
    // $$ *********************
    // ************************
    split_by_indexed_regexes(
      #([#(double_dollar_indexed_regex, "DoubleDollar")], []),
    ),
    pair_bookends(#(["DoubleDollar"], ["DoubleDollar"], "MathBlock")),
    fold_tags_into_text(dict.from_list([#("DoubleDollar", "$$")])),
    remove_empty_lines(),
    // ************************
    // AddTitleCounters *******
    // ************************
    add_title_counters_and_titles([
      #("Chapter", "ExampleCounter", "Example", "*Example ", ".*"),
      #("Exercises", "ExerciseCounter", "Exercise", "*Exercise ", ".*"),
      #("Solution", "NotesCounter", "Note", "_Note ", "._"),
    ]),
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
    split_by_indexed_regexes(
      #([#(single_dollar_indexed_regex, "SingleDollar")], []),
    ),
    pair_bookends(#(["SingleDollar"], ["SingleDollar"], "Math")),
    fold_tags_into_text(dict.from_list([#("SingleDollar", "$")])),
    remove_empty_lines(),
    // ************************
    // __ *********************
    // ************************
    split_by_indexed_regexes(
      #(
        [
          #(opening_double_underscore_indexed_regex, "OpeningDoubleUnderscore"),
          #(closing_double_underscore_indexed_regex, "ClosingDoubleUnderscore"),
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
    // ************************
    // _| |_ ******************
    // ************************
    split_by_indexed_regexes(
      #(
        [
          #(opening_central_quote_indexed_regex, "OpeningCenterQuote"),
          #(closing_central_quote_indexed_regex, "ClosingCenterQuote"),
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
    // break CenterDisplay &
    // CentralItalicDisplay out
    // of VerticalChunk
    // ************************
    free_children([
      #("CenterDisplay", "VerticalChunk"),
      #("CentralItalicDisplay", "VerticalChunk"),
    ]),
    // ************************
    // _ & * ******************
    // ************************
    split_by_indexed_regexes(
      #(
        [
          #(opening_single_underscore_indexed_regex, "OpeningUnderscore"),
          #(
            opening_or_closing_single_underscore_indexed_regex,
            "OpeningOrClosingUnderscore",
          ),
          #(closing_single_underscore_indexed_regex, "ClosingUnderscore"),
          #(opening_single_asterisk_indexed_regex, "OpeningAsterisk"),
          #(
            opening_or_closing_single_asterisk_indexed_regex,
            "OpeningOrClosingAsterisk",
          ),
          #(closing_single_asterisk_indexed_regex, "ClosingAsterisk"),
          #(opening_single_underscore_indexed_regex, "OpeningUnderscore"),
          #(
            opening_or_closing_single_underscore_indexed_regex_with_asterisks,
            "OpeningOrClosingUnderscore",
          ),
          #(closing_single_underscore_indexed_regex, "ClosingUnderscore"),
        ],
        ["MathBlock", "Math"],
      ),
    ),
    pair_bookends(#(
      ["OpeningUnderscore", "OpeningOrClosingUnderscore"],
      ["ClosingUnderscore", "OpeningOrClosingUnderscore"],
      "i",
    )),
    pair_bookends(#(
      ["OpeningAsterisk", "OpeningOrClosingAsterisk"],
      ["ClosingAsterisk", "OpeningOrClosingAsterisk"],
      "b",
    )),
    fold_tags_into_text(
      dict.from_list([
        #("OpeningOrClosingUnderscore", "_"),
        #("OpeningUnderscore", "_"),
        #("ClosingUnderscore", "_"),
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
    counter_desugarer(),
    counter_handles_desugarer(),
    add_exercise_labels(),
    add_counter_attributes([#("Solution", "Exercises", "solution_number", 0)]),
    concatenate_text_nodes(),
  ]
}
