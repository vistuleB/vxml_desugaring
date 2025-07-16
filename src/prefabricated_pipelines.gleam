import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import vxml
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
import desugarer_library as dl
import nodemaps_2_desugarer_transforms as n2t

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
        dl.split_by_indexed_regexes(#([#(ind_regex, tag)], forbidden)),
        dl.pair_bookends(#([tag], [tag], wrapper)),
        dl.fold_tags_into_text([#(tag, replacement)])
      ]
    }

    False -> {
      let #(ind_regex1, tag1, replacement1) = all_stuff_for_latex_delimiter_singleton(d1)
      let #(ind_regex2, tag2, replacement2) = all_stuff_for_latex_delimiter_singleton(d2)
      [
        dl.split_by_indexed_regexes(#([#(ind_regex1, tag1), #(ind_regex2, tag2)], forbidden)),
        dl.pair_bookends(#([tag1], [tag2], wrapper)),
        dl.fold_tags_into_text([#(tag1, replacement1), #(tag2, replacement2)])
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
    dl.insert_bookend_tags([
      #("MathBlock", "MathBlockOpening", "MathBlockClosing"),
      #("Math", "MathOpening", "MathClosing"),
    ]),
    dl.fold_tags_into_text([
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
) -> Desugarer {
  let #(s1, s2) = opening_and_closing_string_for_pair(with)

  infrastructure.Desugarer(
    "normalize_begin_end_align",
    Some(ins(with)),
    "
/// adds delimiters around \\begin{align} and \\end{align} if not already present
    ",
    normalize_begin_end_align_transform(s1, s2)
  )
}

fn normalize_begin_end_align_transform(s1: String, s2: String) -> infrastructure.DesugarerTransform {

  let nodemap = fn(node: vxml.VXML) -> Result(vxml.VXML, infrastructure.DesugaringError) {
    case node {
      vxml.V(_, _, _, _) -> Ok(node)
      vxml.T(blame, blamed_contents) -> {
        let processed_contents = process_blamed_contents_for_align_delimiters(blamed_contents, s1, s2)
        Ok(vxml.T(blame, processed_contents))
      }
    }
  }

  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap)
}

fn process_blamed_contents_for_align_delimiters(
  contents: List(vxml.BlamedContent),
  s1: String,
  s2: String
) -> List(vxml.BlamedContent) {
  contents
  |> list.map(fn(blamed_content) {
    let processed_text = process_text_for_align_delimiters(blamed_content.content, s1, s2)
    vxml.BlamedContent(..blamed_content, content: processed_text)
  })
}

fn process_text_for_align_delimiters(text: String, s1: String, s2: String) -> String {
  text
  |> process_begin_align_delimiters(s1)
  |> process_end_align_delimiters(s2)
}

fn process_begin_align_delimiters(text: String, s1: String) -> String {
  process_align_pattern(text, "\\begin{align*}", s1, True)
  |> process_align_pattern("\\begin{align}", s1, True)
}

fn process_end_align_delimiters(text: String, s2: String) -> String {
  process_align_pattern(text, "\\end{align*}", s2, False)
  |> process_align_pattern("\\end{align}", s2, False)
}

fn process_align_pattern(text: String, pattern: String, delimiter: String, is_opening: Bool) -> String {
  case string.contains(text, pattern) {
    False -> text
    True -> {
      let parts = string.split(text, pattern)
      process_align_parts(parts, pattern, delimiter, is_opening, [])
    }
  }
}

fn process_align_parts(
  parts: List(String),
  pattern: String,
  delimiter: String,
  is_opening: Bool,
  acc: List(String)
) -> String {
  case parts {
    [] -> string.join(list.reverse(acc), "")
    [single] -> string.join(list.reverse([single, ..acc]), "")
    [before, ..rest] -> {
      let should_add_delimiter = case is_opening {
        True -> !text_ends_with_delimiter_ignoring_whitespace(before, delimiter)
        False -> case rest {
          [after, ..] -> !text_starts_with_delimiter_ignoring_whitespace(after, delimiter)
          [] -> False
        }
      }

      let new_part = case should_add_delimiter, is_opening {
        True, True -> before <> delimiter <> pattern
        True, False -> before <> pattern <> delimiter
        False, _ -> before <> pattern
      }

      process_align_parts(rest, pattern, delimiter, is_opening, [new_part, ..acc])
    }
  }
}

fn text_ends_with_delimiter_ignoring_whitespace(text: String, delimiter: String) -> Bool {
  let trimmed = string.trim_end(text)
  string.ends_with(trimmed, delimiter)
}

fn text_starts_with_delimiter_ignoring_whitespace(text: String, delimiter: String) -> Bool {
  let trimmed = string.trim_start(text)
  string.starts_with(trimmed, delimiter)
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
