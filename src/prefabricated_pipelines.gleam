import gleam/list
import indexed_regex_splitting.{type RegexWithIndexedGroup} as irs
import infrastructure.{
  type Desugarer,
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
import desugarers as ds
// import desugarers/split_by_indexed_regexes.{split_by_indexed_regexes}
// import desugarers/pair_bookends.{pair_bookends}
// import desugarers/fold_tags_into_text.{fold_tags_into_text}
// import desugarers/insert_bookend_tags.{insert_bookend_tags}

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
) -> List(Desugarer) {
  let #(d1, d2) = opening_and_closing_singletons_for_pair(pair)
  case closing_equals_opening(pair) {
    True -> {
      let #(ind_regex, tag, replacement) = all_stuff_for_latex_delimiter_singleton(d1)
      [
        ds.split_by_indexed_regexes(#([#(ind_regex, tag)], forbidden)),
        ds.pair_bookends(#([tag], [tag], wrapper)),
        ds.fold_tags_into_text([#(tag, replacement)])
      ]
    }

    False -> {
      let #(ind_regex1, tag1, replacement1) = all_stuff_for_latex_delimiter_singleton(d1)
      let #(ind_regex2, tag2, replacement2) = all_stuff_for_latex_delimiter_singleton(d2)
      [
        ds.split_by_indexed_regexes(#([#(ind_regex1, tag1), #(ind_regex2, tag2)], forbidden)),
        ds.pair_bookends(#([tag1], [tag2], wrapper)),
        ds.fold_tags_into_text([#(tag1, replacement1), #(tag2, replacement2)])
      ]
    }
  }
}

pub fn create_mathblock_and_math_elements(
  display_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
  single_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
) -> List(Desugarer) {
  let #(display_math_delimiters, display_math_default_delimeters) = display_math_delimiters
  let #(single_math_delimiters, inline_math_default_delimeters) = single_math_delimiters

  let normalization = [
    ds.rename(#("MathBlock", "UserDefinedMathBlock")),
    ds.normalize_math_delimiters_inside(#(["UserDefinedMathBlock"], DoubleDollar))
  ]

  let de_normalization = [
    ds.rename(#("UserDefinedMathBlock", "MathBlock")),
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
    ds.insert_bookend_tags([
      #("MathBlock", "MathBlockOpening", "MathBlockClosing"),
      #("Math", "MathOpening", "MathClosing"),
    ]),
    ds.fold_tags_into_text([
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
) -> List(Desugarer) {
  let #(s1, s2) = opening_and_closing_string_for_pair(with)

  let opening = irs.unescaped_suffix_indexed_regex("\\\\begin\\{align\\*\\}")
  let closing = irs.unescaped_suffix_indexed_regex("\\\\end\\{align\\*\\}")

  let opening2 = irs.unescaped_suffix_indexed_regex("\\\\begin\\{align\\}")
  let closing2 = irs.unescaped_suffix_indexed_regex("\\\\end\\{align\\}")

  [
    ds.split_by_indexed_regexes(#([
      #(opening, "BeginAlignStar"),
      #(closing, "EndAlignStar"),
      #(opening2, "BeginAlign"),
      #(closing2, "EndAlign"),
    ], [])),
    ds.fold_tags_into_text([
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
) -> List(Desugarer) {
  let opening_ir = irs.l_m_r_1_3_indexed_regex_no_middle_par("[\\s]", irs.unescaped_suffix(delim_regex_form), "[^\\s)\\]}]|$")
  let opening_or_closing_ir = irs.l_m_r_1_3_indexed_regex_no_middle_par("[^\\s]|^", irs.unescaped_suffix(delim_regex_form), "[^\\s)\\]}]|$")
  let closing_ir = irs.l_m_r_1_3_indexed_regex_no_middle_par("[^\\s]|^", irs.unescaped_suffix(delim_regex_form), "[\\s)\\]}]")
  [
    ds.split_by_indexed_regexes(#(
        [
          #(opening_or_closing_ir, "OpeningOrClosingSymmetricDelim"),
          #(opening_or_closing_ir, "OpeningOrClosingSymmetricDelim"), // need second guy for this pattern: Gr_i_gorinovich (or second occurrence is shadowed by first occurrence)
          #(opening_ir, "OpeningSymmetricDelim"),
          #(closing_ir, "ClosingSymmetricDelim"),
        ],
        forbidden,
    )),
    ds.pair_bookends(#(
      ["OpeningSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      ["ClosingSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      tag,
    )),
    ds.fold_tags_into_text([
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
) -> List(Desugarer) {
  let opening_central_quote_indexed_regex = irs.l_m_r_1_3_indexed_regex("[\\s]|^", opening_regex_form, "[^\\s]|$")
  let closing_central_quote_indexed_regex = irs.l_m_r_1_3_indexed_regex("[^\\s]|^", closing_regex_form, "[\\s]|$")
  [
    ds.split_by_indexed_regexes(#(
      [
        #(opening_central_quote_indexed_regex, "OpeningAsymmetricDelim"),
        #(closing_central_quote_indexed_regex, "ClosingAsymmetricDelim"),
      ],
      forbidden,
    )),
    ds.pair_bookends(#(
      ["OpeningAsymmetricDelim"],
      ["ClosingAsymmetricDelim"],
      tag
    )),
    ds.fold_tags_into_text([
      #("OpeningAsymmetricDelim", opening_ordinary_form),
      #("ClosingAsymmetricDelim", closing_ordinary_form),
    ]),
  ]
}
