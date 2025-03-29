import gleam/list
import indexed_regex_splitting.{type RegexWithIndexedGroup} as irs
import infrastructure.{type Pipe}
import desugarers/split_by_indexed_regexes.{split_by_indexed_regexes}
import desugarers/pair_bookends.{pair_bookends}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_bookend_tags.{insert_bookend_tags}

//******************
// math delimiter stuff
//******************

type LatexDelimiter {
  DoubleDollarDelimiter
  SingleDollarDelimiter
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

fn opening_and_closing_delimiter_for_pair(
  pair: LatexDelimiterPair
) -> #(LatexDelimiter, LatexDelimiter) {
  case pair {
    DoubleDollar -> #(DoubleDollarDelimiter, DoubleDollarDelimiter)
    SingleDollar -> #(SingleDollarDelimiter, SingleDollarDelimiter)
    BackslashParenthesis -> #(BackslashOpeningParenthesis, BackslashClosingParenthesis)
    BackslashSquareBracket -> #(BackslashOpeningSquareBracket, BackslashClosingSquareBracket)
  }
}

fn opening_and_closing_string_for_pair(
  pair: LatexDelimiterPair
) -> #(String, String) {
  case pair {
    DoubleDollar -> #("$$", "$$")
    SingleDollar -> #("$", "$")
    BackslashParenthesis -> #("\\(", "\\)")
    BackslashSquareBracket -> #("\\[", "\\]")
  }
}

fn indexed_regex_tag_and_unpaired_replacement_for_latex_delimiter(
  which: LatexDelimiter
) -> #(RegexWithIndexedGroup, String, String) {
  case which {
    DoubleDollarDelimiter -> #(irs.unescaped_suffix_indexed_regex("\\$\\$"), "DoubleDollar", "$$")
    SingleDollarDelimiter -> #(irs.unescaped_suffix_indexed_regex("\\$"), "SingleDollar", "$")
    BackslashOpeningParenthesis -> #(irs.unescaped_suffix_indexed_regex("\\\\\\("), "LatexOpeningPar", "\\(")
    BackslashClosingParenthesis -> #(irs.unescaped_suffix_indexed_regex("\\\\\\)"), "LatexClosingPar", "\\)")
    BackslashOpeningSquareBracket -> #(irs.unescaped_suffix_indexed_regex("\\\\\\["), "LatexOpeningBra", "\\[")
    BackslashClosingSquareBracket -> #(irs.unescaped_suffix_indexed_regex("\\\\\\]"), "LatexClosingBra", "\\]")
  }
}

fn closing_equals_opening(
  pair: LatexDelimiterPair
) -> Bool {
  case pair {
    DoubleDollar -> True
    SingleDollar -> True
    _ -> False
  }
}

fn split_pair_fold_for_delimiter_pair(
  pair: LatexDelimiterPair,
  wrapper: String,
  forbidden: List(String),
) -> List(Pipe) {
  let #(d1, d2) = opening_and_closing_delimiter_for_pair(pair)
  case closing_equals_opening(pair) {
    True -> {
      let #(ind_regex, tag, replacement) = indexed_regex_tag_and_unpaired_replacement_for_latex_delimiter(d1)
      [
        split_by_indexed_regexes(#([#(ind_regex, tag)], forbidden)),
        pair_bookends(#([tag], [tag], wrapper)),
        fold_tags_into_text([#(tag, replacement)])
      ]
    }

    False -> {
      let #(ind_regex1, tag1, replacement1) = indexed_regex_tag_and_unpaired_replacement_for_latex_delimiter(d1)
      let #(ind_regex2, tag2, replacement2) = indexed_regex_tag_and_unpaired_replacement_for_latex_delimiter(d2)
      [
        split_by_indexed_regexes(#([#(ind_regex1, tag1), #(ind_regex2, tag2)], forbidden)),
        pair_bookends(#([tag1], [tag2], wrapper)),
        fold_tags_into_text([#(tag1, replacement1), #(tag2, replacement2)])
      ]
    }
  }
}

pub fn create_mathblock_and_math_elements(
  display_math_delimiters: List(LatexDelimiterPair),
  single_math_delimiters: List(LatexDelimiterPair),
  display_math_default_delims: #(String, String),
  inline_math_default_delims: #(String, String),
) -> List(Pipe) {
  let display_math_pipe =
    list.map(
      display_math_delimiters,
      split_pair_fold_for_delimiter_pair(_, "MathBlock", ["Math", "MathBlock"])
    )
    |> list.flatten

  let inline_math_pipe =
    list.map(
      single_math_delimiters,
      split_pair_fold_for_delimiter_pair(_, "Math", ["Math", "MathBlock"])
    )
    |> list.flatten

  let #(a, b) = display_math_default_delims
  let #(c, d) = inline_math_default_delims

  let reinserting_delims_pipe = [
    insert_bookend_tags([
      #("MathBlock", "MathBlockOpening", "MathBlockClosing"),
      #("Math", "MathOpening", "MathClosing"),
    ]),
    fold_tags_into_text([
      #("MathBlockOpening", a),
      #("MathBlockClosing", b),
      #("MathOpening", c),
      #("MathClosing", d),
    ]),
  ]

  [
    display_math_pipe,
    inline_math_pipe,
    reinserting_delims_pipe,
  ]
  |> list.flatten
}

pub fn normalize_begin_end_align_star(
  with: LatexDelimiterPair,
) -> List(Pipe) {
  let opening = irs.unescaped_suffix_indexed_regex("\\\\begin\\{align\\*\\}")
  let closing = irs.unescaped_suffix_indexed_regex("\\\\end\\{align\\*\\}")
  let #(s1, s2) = opening_and_closing_string_for_pair(with)
  [
    split_by_indexed_regexes(#([
      #(opening, "BeginAlignStar"),
      #(closing, "EndAlignStar")
    ], [])),
    fold_tags_into_text([
      #("BeginAlignStar", s1 <> "\\begin{align*}"),
      #("EndAlignStar", "\\end{align*}" <> s2),
    ])
  ]
}

//***************
// double underscore stuff
//***************

pub fn symmetric_delim_splitting(
  delim_regex_form: String,
  delim_ordinary_form: String,
  tag: String,
  forbidden: List(String),
) -> List(Pipe) {
  let opening_ir = irs.l_m_r_1_3_indexed_regex("[\\s]|^", delim_regex_form, "[^\\s]|$")
  let opening_or_closing_ir = irs.l_m_r_1_3_indexed_regex("[^\\s]|^", delim_regex_form, "[^\\s]|$")
  let closing_ir = irs.l_m_r_1_3_indexed_regex("[^\\s]|^", delim_regex_form, "[\\s]|$")
  [
    split_by_indexed_regexes(#(
        [
          #(opening_or_closing_ir, "OpeningOrClosingSymmetricDelim"),
          #(opening_ir, "OpeningSymmetricDelim"),
          #(closing_ir, "ClosingSymmetricDelim"),
        ],
        forbidden,
    )),
    pair_bookends(#(
      ["OpeningSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      ["ClosingSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      tag,
    )),
    fold_tags_into_text([
      #("OpeningSymmetricDelim", delim_ordinary_form),
      #("ClosingSymmetricDelim", delim_ordinary_form),
      #("OpeningOrClosingSymmetricDelim", delim_ordinary_form),
    ]),
  ]
}

pub fn asymmetric_delim_splitting(
  opening_regex_form: String,
  closing_regex_form: String,
  opening_ordinary_form: String,
  closing_ordinary_form: String,
  tag: String,
  forbidden: List(String),
) -> List(Pipe) {
  let opening_central_quote_indexed_regex = irs.l_m_r_1_3_indexed_regex("[\\s]|^", opening_regex_form, "[^\\s]|$")
  let closing_central_quote_indexed_regex = irs.l_m_r_1_3_indexed_regex("[^\\s]|^", closing_regex_form, "[\\s]|$")
  [
    split_by_indexed_regexes(#(
      [
        #(opening_central_quote_indexed_regex, "OpeningAsymmetricDelim"),
        #(closing_central_quote_indexed_regex, "ClosingAsymmetricDelim"),
      ],
      forbidden,
    )),
    pair_bookends(#(
      ["OpeningAsymmetricDelim"],
      ["ClosingAsymmetricDelim"],
    tag)),
    fold_tags_into_text([
      #("OpeningAsymmetricDelim", opening_ordinary_form),
      #("ClosingAsymmetricDelim", closing_ordinary_form),
    ]),
  ]
}

// pub fn underscore_and_asterisk_delim_splitting(
//   underscore_tag: String,
//   asterisk_tag: String,
//   forbidden: List(String),
// ) -> List(Pipe) {
//   // I don't remember why we had to split these together or why the complicated
//   // with/without askteriks for underscore, but if you split them together you
//   // need that with/without to avoid a bug, I remember that much

//   // _ _
//   let opening_single_underscore_indexed_regex =
//     irs.l_m_r_1_3_indexed_regex("[\\s({\\[]|^", "_", "[^\\s)}\\]_]|$")
//   let opening_or_closing_single_underscore_indexed_regex_without_asterisks =
//     irs.l_m_r_1_3_indexed_regex("[^\\s({\\[\\*_]|^", "_", "[^\\s)}\\]\\*_]|$")
//   let opening_or_closing_single_underscore_indexed_regex_with_asterisks =
//     irs.l_m_r_1_3_indexed_regex("[^\\s({\\[_]|^", "_", "[^\\s)}\\]_]|$")
//   let closing_single_underscore_indexed_regex =
//     irs.l_m_r_1_3_indexed_regex("[^\\s({\\[_]|^", "_", "[\\s)}\\]]|$")

//   // * *
//   let opening_single_asterisk_indexed_regex =
//     irs.l_m_r_1_3_indexed_regex("[\\s({\\[]|^", "\\*", "[^\\s)}\\]\\*]|$")
//   let opening_or_closing_single_asterisk_indexed_regex =
//     irs.l_m_r_1_3_indexed_regex("[^\\s({\\[\\*]|^", "\\*", "[^\\s)}\\]\\*]|$")
//   let closing_single_asterisk_indexed_regex =
//     irs.l_m_r_1_3_indexed_regex("[^\\s({\\[\\*]|^", "\\*", "[\\s)}\\]]|$")

//   [
//     split_by_indexed_regexes(#(
//       [
//         // "_"
//         #(opening_or_closing_single_underscore_indexed_regex_without_asterisks, "OpeningOrClosingUnderscore"),
//         #(opening_single_underscore_indexed_regex, "OpeningUnderscore"),
//         #(closing_single_underscore_indexed_regex, "ClosingUnderscore"),
//         // "*"
//         #(opening_or_closing_single_asterisk_indexed_regex, "OpeningOrClosingAsterisk"),
//         #(opening_single_asterisk_indexed_regex, "OpeningAsterisk"),
//         #(closing_single_asterisk_indexed_regex, "ClosingAsterisk"),
//         // "_"
//         #(opening_or_closing_single_underscore_indexed_regex_with_asterisks, "OpeningOrClosingUnderscore"),
//         #(opening_single_underscore_indexed_regex, "OpeningUnderscore"),
//         #(closing_single_underscore_indexed_regex, "ClosingUnderscore"),
//       ],
//       forbidden,
//     )),
//     pair_bookends(#(
//       ["OpeningUnderscore", "OpeningOrClosingUnderscore"],
//       ["ClosingUnderscore", "OpeningOrClosingUnderscore"],
//       underscore_tag,
//     )),
//     pair_bookends(#(
//       ["OpeningAsterisk", "OpeningOrClosingAsterisk"],
//       ["ClosingAsterisk", "OpeningOrClosingAsterisk"],
//       asterisk_tag,
//     )),
//     fold_tags_into_text([
//       #("OpeningOrClosingUnderscore", "_"),
//       #("OpeningUnderscore", "_"),
//       #("ClosingUnderscore", "_"),
//       #("OpeningOrClosingAsterisk", "*"),
//       #("OpeningAsterisk", "*"),
//       #("ClosingAsterisk", "*"),
//     ]),
//   ]
// }
