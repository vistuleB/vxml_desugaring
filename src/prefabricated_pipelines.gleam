import indexed_regex_splitting as irs
import gleam/list
import group_replacement_splitting as grs
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
import desugarer_library as dl

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
) -> #(grs.RegexpWithGroupReplacementInstructions, String, String) {
  case which {
    DoubleDollarSingleton -> #(grs.unescaped_suffix_replacement_splitter("\\$\\$", "DoubleDollar"), "DoubleDollar", "$$")
    SingleDollarSingleton -> #(grs.unescaped_suffix_replacement_splitter("\\$", "SingleDollar"), "SingleDollar", "$")
    BackslashOpeningParenthesis -> #(grs.unescaped_suffix_replacement_splitter("\\\\\\(", "LatexOpeningPar"), "LatexOpeningPar", "\\(")
    BackslashClosingParenthesis -> #(grs.unescaped_suffix_replacement_splitter("\\\\\\)", "LatexClosingPar"), "LatexClosingPar", "\\)")
    BackslashOpeningSquareBracket -> #(grs.unescaped_suffix_replacement_splitter("\\\\\\[", "LatexOpeningBra"), "LatexOpeningBra", "\\[")
    BackslashClosingSquareBracket -> #(grs.unescaped_suffix_replacement_splitter("\\\\\\]", "LatexClosingBra"), "LatexClosingBra", "\\]")
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
        dl.split_with_replacement_instructions(#([ind_regex], forbidden)),
        dl.pair_bookends(#([tag], [tag], wrapper)),
        dl.fold_tags_into_text([#(tag, replacement)])
      ]
    }
    False -> {
      let #(ind_regex1, tag1, replacement1) = all_stuff_for_latex_delimiter_singleton(d1)
      let #(ind_regex2, tag2, replacement2) = all_stuff_for_latex_delimiter_singleton(d2)
      [
        dl.split_with_replacement_instructions(#([ind_regex1, ind_regex2], forbidden)),
        dl.pair_bookends(#([tag1], [tag2], wrapper)),
        dl.fold_tags_into_text([#(tag1, replacement1), #(tag2, replacement2)])
      ]
    }
  }
}

pub fn create_mathblock_elements(
  display_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
) -> List(Desugarer) {
  let #(display_math_delimiters, display_math_default_delimeters) = display_math_delimiters
  let normalization = [
    dl.rename(#("MathBlock", "UserDefinedMathBlock")),
    dl.normalize_math_delimiters_inside(#(["UserDefinedMathBlock"], DoubleDollar))
  ]
  let de_normalization = [
    dl.rename(#("UserDefinedMathBlock", "MathBlock")),
  ]
  let display_math_pipe =
    list.map(
      display_math_delimiters,
      split_pair_fold_for_delimiter_pair(_, "MathBlock", ["Math", "MathBlock", "UserDefinedMathBlock"])
    )
    |> list.flatten
  let #(a, b) = opening_and_closing_string_for_pair(display_math_default_delimeters)
  let reinserting_delims_pipe = [
    dl.insert_bookend_text([#("MathBlock", a, b)]),
    // dl.insert_bookend_tags([
    //   #("MathBlock", "MathBlockOpening", "MathBlockClosing"),
    // ]),
    // dl.fold_tags_into_text([
    //   #("MathBlockOpening", a),
    //   #("MathBlockClosing", b),
    // ]),
  ]
  [
    normalization,
    display_math_pipe,
    reinserting_delims_pipe,
    de_normalization,
  ]
  |> list.flatten
}

pub fn create_mathblock_and_math_elements(
  display_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
  single_math_delimiters: #(List(LatexDelimiterPair), LatexDelimiterPair),
) -> List(Desugarer) {
  let #(display_math_delimiters, display_math_default_delimeters) = display_math_delimiters
  let #(single_math_delimiters, inline_math_default_delimeters) = single_math_delimiters

  let normalization = [
    dl.rename(#("MathBlock", "UserDefinedMathBlock")),
    dl.normalize_math_delimiters_inside(#(["UserDefinedMathBlock"], DoubleDollar))
  ]

  let de_normalization = [
    dl.rename(#("UserDefinedMathBlock", "MathBlock")),
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
    dl.insert_bookend_text([#("MathBlock", a, b)]),
    dl.insert_bookend_text([#("Math", c, d)]),
    // dl.insert_bookend_tags([
    //   #("MathBlock", "MathBlockOpening", "MathBlockClosing"),
    //   #("Math", "MathOpening", "MathClosing"),
    // ]),
    // dl.fold_tags_into_text([
    //   #("MathBlockOpening", a),
    //   #("MathBlockClosing", b),
    //   #("MathOpening", c),
    //   #("MathClosing", d),
    // ]),
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
    dl.split_by_indexed_regexes(#(
        [
          #(opening_or_closing_ir, "OpeningOrClosingSymmetricDelim"),
          #(opening_or_closing_ir, "OpeningOrClosingSymmetricDelim"), // need second guy for this pattern: Gr_i_gorinovich (or second occurrence is shadowed by first occurrence)
          #(opening_ir, "OpeningSymmetricDelim"),
          #(closing_ir, "ClosingSymmetricDelim"),
        ],
        forbidden,
    )),
    dl.pair_bookends(#(
      ["OpeningSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      ["ClosingSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      tag,
    )),
    dl.fold_tags_into_text([
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
    dl.split_by_indexed_regexes(#(
      [
        #(opening_central_quote_indexed_regex, "OpeningAsymmetricDelim"),
        #(closing_central_quote_indexed_regex, "ClosingAsymmetricDelim"),
      ],
      forbidden,
    )),
    dl.pair_bookends(#(
      ["OpeningAsymmetricDelim"],
      ["ClosingAsymmetricDelim"],
      tag
    )),
    dl.fold_tags_into_text([
      #("OpeningAsymmetricDelim", opening_ordinary_form),
      #("ClosingAsymmetricDelim", closing_ordinary_form),
    ]),
  ]
}

//***************
// barbaric symmetric & asymmetric delim splitting
//***************

pub fn barbaric_symmetric_delim_splitting(
  delim_regex_form: String,
  delim_ordinary_form: String,
  tag: String,
  forbidden: List(String),
) -> List(Desugarer) {
  let opening_or_closing_grs = grs.unescaped_suffix_replacement_splitter(delim_regex_form, "OpeningOrClosingSymmetricDelim")
  [
    dl.split_with_replacement_instructions(#([opening_or_closing_grs], forbidden)),
    dl.pair_bookends(#(["OpeningOrClosingSymmetricDelim"], ["OpeningOrClosingSymmetricDelim"], tag)),
    dl.fold_tags_into_text([#("OpeningOrClosingSymmetricDelim", delim_ordinary_form)])
  ]
}
