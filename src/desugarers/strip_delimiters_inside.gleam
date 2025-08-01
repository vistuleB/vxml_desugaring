import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V, BlamedContent}

fn remove_first_prefix_found(c: String, prefixes: List(String)) -> String {
  case prefixes {
    [] -> c
    [first, ..rest] -> case string.starts_with(c, first) {
      True -> string.drop_start(c, string.length(first))
      False -> remove_first_prefix_found(c, rest)
    }
  }
}

fn remove_first_suffix_found(c: String, suffixes: List(String)) -> String {
  case suffixes {
    [] -> c
    [first, ..rest] -> case string.ends_with(c, first) {
      True -> string.drop_end(c, string.length(first))
      False -> remove_first_suffix_found(c, rest)
    }
  }
}

fn strip(
  t: VXML,
  inner: InnerParam,
) -> VXML {
  let assert T(_, lines) = t
  let lines = infra.lines_trim_start(lines)
  let assert [first, ..rest] = lines
  let lines = [
    BlamedContent(..first, content: remove_first_prefix_found(first.content, inner.1)),
    ..rest
  ]
  let lines = infra.reversed_lines_trim_end(lines |> list.reverse)
  let assert [first, ..rest] = lines
  let lines = [
    BlamedContent(..first, content: remove_first_suffix_found(first.content, inner.2)),
    ..rest
  ] |> list.reverse
  T(..t, contents: lines)
}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    V(_, tag, _, children) if tag == inner.0 -> case children {
      [T(_, _) as t] -> Ok(V(..node, children: [strip(t, inner)]))
      _ -> Error(DesugaringError(node.blame, "expecting unique text child in target tag"))
    }
    _ -> Ok(node)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

type Param = #(String,    List(infra.LatexDelimiterPair))
//             ↖          ↖
//             tag        delimiters
//             to target  to remove
type InnerParam = #(String, List(String), List(String))

const name = "strip_delimiters_inside"
const constructor = strip_delimiters_inside

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// strips all Latex delimiters inside a targeted
/// tag name; if called with tag "MathBlock", for
/// example, will turn
/// ```
/// <> MathBlock
///   <>
///     "$$x$$"
/// ```
/// and
/// ```
/// <> MathBlock
///   <>
///     "\[x\]"
/// ```
/// and
/// ```
/// <> MathBlock
///   <>
///     "$$x\]"
/// ```
/// (even if this is a Mathjax error), into
/// ```
/// <> MathBlock
///   <>
///     "x"
/// ```
/// .
pub fn strip_delimiters_inside(param: Param) -> Desugarer {
  let #(opening, closing) = infra.left_right_delim_strings(param.1)
  let inner = #(param.0, opening, closing)
  Desugarer(
    name,
    option.Some(ins(inner)),
    option.None,
    "
/// Strips all Latex delimiters inside a targeted
/// tag name. If called with tag \"MathBlock\", for
/// example, will turn
/// ```
/// <> MathBlock
///   <>
///     \"$$x$$\"
/// ```
/// and
/// ```
/// <> MathBlock
///   <>
///     \"\\[x\\]\"
/// ```
/// and
/// ```
/// <> MathBlock
///   <>
///     \"$$x\\]\"
/// ```
/// (even if this is a Mathjax error), into
/// ```
/// <> MathBlock
///   <>
///     \"x\"
/// ```
/// .
    ",
    transform_factory(inner),
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  [
    infra.AssertiveTestData(
      param: #("Z", [infra.DoubleDollar]),
      source:   "
                <> root
                  <> Z
                    <>
                      \"$$x$$\"
                  <> W
                    <>
                      \"$$x$$\"
                  <> Z
                    <>
                      \"$x$\"
                ",
      expected: "
                <> root
                  <> Z
                    <>
                      \"x\"
                  <> W
                    <>
                      \"$$x$$\"
                  <> Z
                    <>
                      \"$x$\"
                ",
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}