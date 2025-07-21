import indexed_regex_splitting as irs
import gleam/list
import group_replacement_splitting as grs
import infrastructure.{
  type Desugarer,
  type LatexDelimiterPair,
  type LatexDelimiterSingleton,
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

pub fn create_math_or_mathblock_elements(
  parsed: List(LatexDelimiterPair),
  produced: LatexDelimiterPair,
  which: String,
) -> List(Desugarer) {
  let pair = infra.opening_and_closing_string_for_pair(produced)
  let create_tags =
    parsed
    |> list.map(split_pair_fold_for_delimiter_pair(_, which, ["Math", "MathBlock"]))
    |> list.flatten

  [
    [dl.strip_math_delimiters_inside(which)],
    create_tags,
    [dl.insert_bookend_text([#(which, pair.0, pair.1)])],
  ]
  |> list.flatten
}

pub fn create_mathblock_elements(
  parsed: List(LatexDelimiterPair),
  produced: LatexDelimiterPair,
) -> List(Desugarer) {
  create_math_or_mathblock_elements(parsed, produced, "MathBlock")
}

pub fn create_math_elements(
  parsed: List(LatexDelimiterPair),
  produced: LatexDelimiterPair,
) -> List(Desugarer) {
  create_math_or_mathblock_elements(parsed, produced, "Math")
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
  let opening_gri = grs.for_groups([
    #("[\\s]",                                    grs.Keep),
    #(delim_regex_form,                           grs.TagReplace("OpeningSymmetricDelim")),
    #("[^\\s\\]})]|$",                            grs.Keep),
  ])
  let opening_or_closing_gri = grs.for_groups([
    #("[^\\s]|^",                                 grs.Keep),
    #(irs.unescaped_suffix(delim_regex_form),     grs.TagReplace("OpeningOrClosingSymmetricDelim")),
    #("[^\\s\\]})]|$",                            grs.Keep),
  ])
  let closing_gri = grs.for_groups([
    #("[^\\s\\[{(]|^",                            grs.Keep),
    #(irs.unescaped_suffix(delim_regex_form),     grs.TagReplace("ClosingSymmetricDelim")),
    #("[\\s\\]})]",                               grs.Keep),
  ])

  // let opening_ir = irs.l_m_r_1_3_indexed_regex("[\\s]", delim_regex_form, "[^\\s)\\]}]|$")
  // let opening_or_closing_ir = irs.l_m_r_1_3_indexed_regex("[^\\s]|^", irs.unescaped_suffix(delim_regex_form), "[^\\s)\\]}]|$")
  // let closing_ir = irs.l_m_r_1_3_indexed_regex("[^\\s\\[\\{]|^", irs.unescaped_suffix(delim_regex_form), "[\\s)\\]}]")
  // [
  //   dl.split_by_indexed_regexes(#(
  //     [
  //       #(opening_or_closing_ir, "OpeningOrClosingSymmetricDelim"),
  //       #(opening_ir, "OpeningSymmetricDelim"),
  //       #(closing_ir, "ClosingSymmetricDelim"),
  //     ],
  //     forgidden,
  //   )),
  [
    dl.split_with_replacement_instructions(#([opening_or_closing_gri, opening_gri, closing_gri], forbidden)),
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
  let opening_grs = grs.for_groups([
    #("[\\s]|^", grs.Keep),
    #(opening_regex_form, grs.TagReplace("OpeningAsymmetricDelim")),
    #("[^\\s]|$", grs.Keep),
  ])
  let closing_grs = grs.for_groups([
    #("[^\\s]|^", grs.Keep),
    #(closing_regex_form, grs.TagReplace("ClosingAsymmetricDelim")),
    #("[\\s]|$", grs.Keep),
  ])

  // let opening_central_quote_indexed_regex = irs.l_m_r_1_3_indexed_regex("[\\s]|^", opening_regex_form, "[^\\s]|$")
  // let closing_central_quote_indexed_regex = irs.l_m_r_1_3_indexed_regex("[^\\s]|^", closing_regex_form, "[\\s]|$")
  [
    // dl.split_by_indexed_regexes(#(
    //   [
    //     #(opening_central_quote_indexed_regex, "OpeningAsymmetricDelim"),
    //     #(closing_central_quote_indexed_regex, "ClosingAsymmetricDelim"),
    //   ],
    dl.split_with_replacement_instructions(#([opening_grs, closing_grs], forbidden)),
    dl.pair_bookends(#(["OpeningAsymmetricDelim"], ["ClosingAsymmetricDelim"], tag )),
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
