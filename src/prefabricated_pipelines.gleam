import indexed_regex_splitting as irs
import gleam/list
import gleam/pair
import group_replacement_splitting as grs
import infrastructure.{
  type Desugarer,
  type LatexDelimiterPair,
  type LatexDelimiterSingleton,
  DoubleDollar,
  SingleDollar,
  DoubleDollarSingleton,
  SingleDollarSingleton,
  BackslashOpeningParenthesis,
  BackslashClosingParenthesis,
  BackslashOpeningSquareBracket,
  BackslashClosingSquareBracket,
} as infra
import desugarer_library as dl

//******************
// math delimiter stuff
//******************

fn closing_equals_opening(
  pair: LatexDelimiterPair
) -> Bool {
  let z = infra.opening_and_closing_singletons_for_pair(pair)
  z.0 == z.1
}

fn split_pair_fold_data(
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

fn split_pair_fold_for_delimiter_pair(
  pair: LatexDelimiterPair,
  wrapper: String,
  forbidden: List(String),
) -> List(Desugarer) {
  let #(d1, d2) = infra.opening_and_closing_singletons_for_pair(pair)
  case closing_equals_opening(pair) {
    True -> {
      let #(g, tag, original) = split_pair_fold_data(d1)
      [
        dl.split_with_replacement_instructions(#([g], forbidden)),
        dl.pair_bookends(#([tag], [tag], wrapper)),
        dl.fold_tags_into_text([#(tag, original)])
      ]
    }
    False -> {
      let #(g1, tag1, replacement1) = split_pair_fold_data(d1)
      let #(g2, tag2, replacement2) = split_pair_fold_data(d2)
      [
        dl.split_with_replacement_instructions(#([g1, g2], forbidden)),
        dl.pair_bookends(#([tag1], [tag2], wrapper)),
        dl.fold_tags_into_text([#(tag1, replacement1), #(tag2, replacement2)])
      ]
    }
  }
}

pub fn create_mathblock_elements(
  allowed_delimiters: List(LatexDelimiterPair),
  normative_delimiter: LatexDelimiterPair,
) -> List(Desugarer) {
  let normalization = [
    dl.normalize_math_delimiters_inside(#("MathBlock", normative_delimiter))
  ]
  let display_math_pipe =
    list.map(
      allowed_delimiters,
      split_pair_fold_for_delimiter_pair(_, "MathBlock", ["Math", "MathBlock"])
    )
    |> list.flatten
  let #(a, b) = infra.opening_and_closing_string_for_pair(normative_delimiter)
  let reinserting_delims_pipe = [
    dl.insert_bookend_text([#("MathBlock", a, b)]),
  ]
  [
    normalization,
    display_math_pipe,
    reinserting_delims_pipe,
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
    dl.normalize_math_delimiters_inside(#("MathBlock", DoubleDollar))
  ]

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

  let #(a, b) = infra.opening_and_closing_string_for_pair(display_math_default_delimeters)
  let #(c, d) = infra.opening_and_closing_string_for_pair(inline_math_default_delimeters)

  let reinserting_delims_pipe = [
    dl.insert_bookend_text([#("MathBlock", a, b), #("Math", c, d)]),
  ]
  
  [
    normalization,
    display_math_pipe,
    inline_math_pipe,
    reinserting_delims_pipe,
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
