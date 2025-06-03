import gleam/list
import indexed_regex_splitting.{type RegexWithIndexedGroup} as irs
import infrastructure.{
  type Pipe,
  type LatexDelimiterPair,
  type LatexDelimiterSingleton,
  DoubleDollar, 
  SingleDollar, 
  DoubleDollarSingleton,
  SingleDollarSingleton,
  BackslashParenthesis,
  BackslashOpeningParenthesis,
  BackslashClosingParenthesis,
  BackslashSquareBracket,
  BackslashOpeningSquareBracket,
  BackslashClosingSquareBracket 
}
import desugarers/split_by_indexed_regexes.{split_by_indexed_regexes}
import desugarers/pair_bookends.{pair_bookends}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_bookend_tags.{insert_bookend_tags}
import desugarer_names as dn

//******************
// math delimiter stuff
//******************

fn opening_and_closing_singletons_for_pair(
  pair: LatexDelimiterPair
) -> #(LatexDelimiterSingleton, LatexDelimiterSingleton) {
  case pair {
    DoubleDollar -> #(DoubleDollarSingleton, DoubleDollarSingleton)
    SingleDollar -> #(SingleDollarSingleton, SingleDollarSingleton)
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

fn all_stuff_for_latex_delimiter_singleton(
  which: LatexDelimiterSingleton
) -> #(RegexWithIndexedGroup, String, String) {
  case which {
    DoubleDollarSingleton -> #(irs.unescaped_suffix_indexed_regex("\\$\\$"), "DoubleDollar", "$$")
    SingleDollarSingleton -> #(irs.unescaped_suffix_indexed_regex("\\$"), "SingleDollar", "$")
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
  let #(d1, d2) = opening_and_closing_singletons_for_pair(pair)
  case closing_equals_opening(pair) {
    True -> {
      let #(ind_regex, tag, replacement) = all_stuff_for_latex_delimiter_singleton(d1)
      [
        split_by_indexed_regexes(#([#(ind_regex, tag)], forbidden)),
        pair_bookends(#([tag], [tag], wrapper)),
        fold_tags_into_text([#(tag, replacement)])
      ]
    }

    False -> {
      let #(ind_regex1, tag1, replacement1) = all_stuff_for_latex_delimiter_singleton(d1)
      let #(ind_regex2, tag2, replacement2) = all_stuff_for_latex_delimiter_singleton(d2)
      [
        split_by_indexed_regexes(#([#(ind_regex1, tag1), #(ind_regex2, tag2)], forbidden)),
        pair_bookends(#([tag1], [tag2], wrapper)),
        fold_tags_into_text([#(tag1, replacement1), #(tag2, replacement2)])
      ]
    }
  }
}

pub fn create_mathblock_and_math_elements(
  display_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
  single_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
) -> List(Pipe) {
  let #(display_math_delimiters, display_math_default_delimeters) = display_math_delimiters
  let #(single_math_delimiters, inline_math_default_delimeters) = single_math_delimiters

  let normalization = [
    dn.rename(#("MathBlock", "UserDefinedMathBlock")),
    dn.normalize_math_delimiters_inside(#(["UserDefinedMathBlock"], DoubleDollar))
  ]

   let de_normalization = [
    dn.rename(#("UserDefinedMathBlock", "MathBlock")),
  ]

  let display_math_pipe =
    list.map(
      display_math_delimiters,
      split_pair_fold_for_delimiter_pair(_, "MathBlock", ["Math", "MathBlock", "UserDefinedMathBlock"])
    )
    |> list.flatten

  let inline_math_pipe =
    list.map(
      single_math_delimiters,
      split_pair_fold_for_delimiter_pair(_, "Math", ["Math", "MathBlock", "UserDefinedMathBlock"])
    )
    |> list.flatten

  let #(a, b) = opening_and_closing_string_for_pair(display_math_default_delimeters)
  let #(c, d) = opening_and_closing_string_for_pair(inline_math_default_delimeters)

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
    normalization,
    display_math_pipe,
    inline_math_pipe,
    reinserting_delims_pipe,
    de_normalization,
  ]
  |> list.flatten
}

pub fn normalize_begin_end_align(
  with: LatexDelimiterPair,
) -> List(Pipe) {
  let #(s1, s2) = opening_and_closing_string_for_pair(with)

  let opening = irs.unescaped_suffix_indexed_regex("\\\\begin\\{align\\*\\}")
  let closing = irs.unescaped_suffix_indexed_regex("\\\\end\\{align\\*\\}")

  let opening2 = irs.unescaped_suffix_indexed_regex("\\\\begin\\{align\\}")
  let closing2 = irs.unescaped_suffix_indexed_regex("\\\\end\\{align\\}")

  [
    split_by_indexed_regexes(#([
      #(opening, "BeginAlignStar"),
      #(closing, "EndAlignStar"),
      #(opening2, "BeginAlign"),
      #(closing2, "EndAlign"),
    ], [])),
    fold_tags_into_text([
      #("BeginAlignStar", s1 <> "\\begin{align*}"),
      #("EndAlignStar", "\\end{align*}" <> s2),
      #("BeginAlign", s1 <> "\\begin{align}"),
      #("EndAlign", "\\end{align}" <> s2),
    ])
  ]
}

//***************
// generic symmetric & asymmetric delim splitting
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
