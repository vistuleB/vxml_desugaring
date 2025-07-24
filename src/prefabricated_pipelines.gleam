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

fn split_pair_fold_for_delimiter_pair_no_list(
  pair: LatexDelimiterPair,
  wrapper: String,
  forbidden: List(String),
) -> List(Desugarer) {
  let #(d1, d2) = infra.opening_and_closing_singletons_for_pair(pair)
  case closing_equals_opening(pair) {
    True -> {
      let #(g, tag, original) = split_pair_fold_data(d1)
      [
        dl.replace_regex_matches_with_outside(#(g, forbidden)),
        dl.pair(#(tag, tag, wrapper)),
        dl.fold_tag_into_text(#(tag, original))
      ]
    }
    False -> {
      let #(g1, tag1, replacement1) = split_pair_fold_data(d1)
      let #(g2, tag2, replacement2) = split_pair_fold_data(d2)
      [
        dl.replace_regex_matches_with_outside(#(g1, forbidden)),
        dl.replace_regex_matches_with_outside(#(g2, forbidden)),
        dl.pair(#(tag1, tag2, wrapper)),
        dl.fold_tag_into_text(#(tag1, replacement1)),
        dl.fold_tag_into_text(#(tag2, replacement2)),
      ]
    }
  }
}

fn split_pair_fold_for_delimiter_pair(
  pair: LatexDelimiterPair,
  wrapper: String,
  forbidden: List(String),
) -> List(Desugarer) {
  use <- infra.on_lazy_true_on_false(
    infra.no_list,
    fn() {
      split_pair_fold_for_delimiter_pair_no_list(pair, wrapper, forbidden)
    }
  )

  let #(d1, d2) = infra.opening_and_closing_singletons_for_pair(pair)
  case closing_equals_opening(pair) {
    True -> {
      let #(g, tag, original) = split_pair_fold_data(d1)
      [
        dl.split_with_replacement_instructions_plural(#([g], forbidden)),
        dl.pair(#(tag, tag, wrapper)),
        dl.fold_tags_into_text_depr([#(tag, original)])
      ]
    }
    False -> {
      let #(g1, tag1, replacement1) = split_pair_fold_data(d1)
      let #(g2, tag2, replacement2) = split_pair_fold_data(d2)
      [
        dl.split_with_replacement_instructions_plural(#([g1, g2], forbidden)),
        dl.pair(#(tag1, tag2, wrapper)),
        dl.fold_tags_into_text_depr([#(tag1, replacement1), #(tag2, replacement2)])
      ]
    }
  }
}

pub fn create_math_or_mathblock_elements_no_list(
  parsed: List(LatexDelimiterPair),
  produced: LatexDelimiterPair,
  which: String,
) -> List(Desugarer) {
  let pair = infra.opening_and_closing_string_for_pair(produced)
  let create_tags =
    parsed
    |> list.map(split_pair_fold_for_delimiter_pair_no_list(_, which, ["Math", "MathBlock"]))
    |> list.flatten

  let #(left_delims, right_delims) =
    case which {
      "MathBlock" -> infra.latex_display_delimiter_pairs_list()
      _ -> infra.latex_inline_delimiter_pairs_list()
    }
    |> list.map(infra.opening_and_closing_string_for_pair)
    |> list.unzip

  [
    [dl.strip_text_at_start_and_end(#(which, left_delims, right_delims))],
    create_tags,
    [dl.prepend_append_text(#(which, pair.0, pair.1))],
  ]
  |> list.flatten
}

pub fn create_math_or_mathblock_elements(
  parsed: List(LatexDelimiterPair),
  produced: LatexDelimiterPair,
  which: String,
) -> List(Desugarer) {
  use <- infra.on_lazy_true_on_false(
    infra.no_list,
    fn() {create_math_or_mathblock_elements_no_list(parsed, produced, which)}
  )

  let pair = infra.opening_and_closing_string_for_pair(produced)
  let create_tags =
    parsed
    |> list.map(split_pair_fold_for_delimiter_pair(_, which, ["Math", "MathBlock"]))
    |> list.flatten

  // let #(left_delims, right_delims) =
  //   infra.latex_delimiter_pairs_list()
  //   |> list.map(infra.opening_and_closing_string_for_pair)
  //   |> list.unzip

  [
    [dl.strip_math_delimiters_inside(which)],
    // [dl.strip_text_at_start_and_end(#(which, left_delims, right_delims))],
    create_tags,
    [dl.prepend_append_text(#(which, pair.0, pair.1))],
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

pub fn symmetric_delim_splitting_no_list(
  delim_regex_form: String,
  delim_ordinary_form: String,
  tag: String,
  forbidden: List(String),
) -> List(Desugarer) {
  let opening_grs = grs.for_groups([
    #("[\\s]", grs.Keep),
    #(delim_regex_form, grs.Tag("OpeningSymmetricDelim")),
    #("[^\\s\\]})]|$", grs.Keep),
  ])

  let opening_or_closing_grs = grs.for_groups([
    #("[^\\s]|^", grs.Keep),
    #(grs.unescaped_suffix(delim_regex_form), grs.Tag("OpeningOrClosingSymmetricDelim")),
    #("[^\\s\\]})]|$", grs.Keep),
  ])

  let closing_grs = grs.for_groups([
    #("[^\\s\\[{(]|^", grs.Keep),
    #(grs.unescaped_suffix(delim_regex_form), grs.Tag("ClosingSymmetricDelim")),
    #("[\\s\\]})]", grs.Keep),
  ])

  [
    dl.identity(),
    dl.replace_regex_matches_with_outside(#(opening_or_closing_grs, forbidden)),
    dl.replace_regex_matches_with_outside(#(opening_grs, forbidden)),
    dl.replace_regex_matches_with_outside(#(closing_grs, forbidden)),
    dl.pair_list_list(#(
      ["OpeningSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      ["ClosingSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      tag,
    )),
    dl.fold_tag_into_text(#("OpeningSymmetricDelim", delim_ordinary_form)),
    dl.fold_tag_into_text(#("ClosingSymmetricDelim", delim_ordinary_form)),
    dl.fold_tag_into_text(#("OpeningOrClosingSymmetricDelim", delim_ordinary_form)),
  ]
}

pub fn symmetric_delim_splitting(
  delim_regex_form: String,
  delim_ordinary_form: String,
  tag: String,
  forbidden: List(String),
) -> List(Desugarer) {
  use <- infra.on_lazy_true_on_false(
    infra.no_list,
    fn() { symmetric_delim_splitting_no_list(delim_regex_form, delim_ordinary_form, tag, forbidden) }
  )

  let opening_grs = grs.for_groups([
    #("[\\s]", grs.Keep),
    #(delim_regex_form, grs.Tag("OpeningSymmetricDelim")),
    #("[^\\s\\]})]|$", grs.Keep),
  ])

  let opening_or_closing_grs = grs.for_groups([
    #("[^\\s]|^", grs.Keep),
    #(grs.unescaped_suffix(delim_regex_form), grs.Tag("OpeningOrClosingSymmetricDelim")),
    #("[^\\s\\]})]|$", grs.Keep),
  ])

  let closing_grs = grs.for_groups([
    #("[^\\s\\[{(]|^", grs.Keep),
    #(grs.unescaped_suffix(delim_regex_form), grs.Tag("ClosingSymmetricDelim")),
    #("[\\s\\]})]", grs.Keep),
  ])

  [
    dl.split_with_replacement_instructions_plural(#([opening_or_closing_grs, opening_grs, closing_grs], forbidden)),
    dl.pair_list_list(#(
      ["OpeningSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      ["ClosingSymmetricDelim", "OpeningOrClosingSymmetricDelim"],
      tag,
    )),
    dl.fold_tags_into_text_depr([
      #("OpeningSymmetricDelim", delim_ordinary_form),
      #("ClosingSymmetricDelim", delim_ordinary_form),
      #("OpeningOrClosingSymmetricDelim", delim_ordinary_form),
    ]),
  ]
}

pub fn asymmetric_delim_splitting_no_list(
  opening_regex_form: String,
  closing_regex_form: String,
  opening_ordinary_form: String,
  closing_ordinary_form: String,
  tag: String,
  forbidden: List(String),
) -> List(Desugarer) {
  let opening_grs = grs.for_groups([
    #("[\\s]|^", grs.Keep),
    #(opening_regex_form, grs.Tag("OpeningAsymmetricDelim")),
    #("[^\\s]|$", grs.Keep),
  ])

  let closing_grs = grs.for_groups([
    #("[^\\s]|^", grs.Keep),
    #(closing_regex_form, grs.Tag("ClosingAsymmetricDelim")),
    #("[\\s]|$", grs.Keep),
  ])

  [
    dl.replace_regex_matches_with_outside(#(opening_grs, forbidden)),
    dl.replace_regex_matches_with_outside(#(closing_grs, forbidden)),
    dl.pair(#("OpeningAsymmetricDelim", "ClosingAsymmetricDelim", tag)),
    dl.fold_tag_into_text(#("OpeningAsymmetricDelim", opening_ordinary_form)),
    dl.fold_tag_into_text(#("ClosingAsymmetricDelim", closing_ordinary_form)),
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
  use <- infra.on_lazy_true_on_false(
    infra.no_list,
    fn() { asymmetric_delim_splitting_no_list(opening_regex_form, closing_regex_form, opening_ordinary_form, closing_ordinary_form, tag, forbidden) }
  )

  let opening_grs = grs.for_groups([
    #("[\\s]|^", grs.Keep),
    #(opening_regex_form, grs.Tag("OpeningAsymmetricDelim")),
    #("[^\\s]|$", grs.Keep),
  ])

  let closing_grs = grs.for_groups([
    #("[^\\s]|^", grs.Keep),
    #(closing_regex_form, grs.Tag("ClosingAsymmetricDelim")),
    #("[\\s]|$", grs.Keep),
  ])

  [
    dl.split_with_replacement_instructions_plural(#([opening_grs, closing_grs], forbidden)),
    dl.pair(#("OpeningAsymmetricDelim", "ClosingAsymmetricDelim", tag )),
    dl.fold_tags_into_text_depr([
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
    dl.replace_regex_matches_with_outside(#(opening_or_closing_grs, forbidden)),
    dl.pair(#("OpeningOrClosingSymmetricDelim", "OpeningOrClosingSymmetricDelim", tag)),
    dl.fold_tag_into_text(#("OpeningOrClosingSymmetricDelim", delim_ordinary_form))
  ]
}
