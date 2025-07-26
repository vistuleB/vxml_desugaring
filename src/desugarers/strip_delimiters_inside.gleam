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

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String,    List(String),    List(String))
//           ↖            ↖                ↖
//           tag          substrings to    substrings to 
//           to target    remove at start  remove at end
type InnerParam = Param

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
  Desugarer(
    name,
    option.Some(ins(param)),
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
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  [
    infra.AssertiveTestData(
      param: #("Z", ["a"], ["b"]),
      source:   "
                <> Z
                  <>
                    \"axb\"
                ",
      expected: "
                <> Z
                  <>
                    \"x\"
                ",
    ),
    infra.AssertiveTestData(
      param: #("Z", ["a", "b"], ["c"]),
      source:   "
                <> Z
                  <>
                    \"ab\"
                ",
      expected: "
                <> Z
                  <>
                    \"b\"
                ",
    ),
    infra.AssertiveTestData(
      param: #("Z", ["a", "b"], ["c"]),
      source:   "
                <> Z
                  <>
                    \"bc\"
                ",
      expected: "
                <> Z
                  <>
                    \"\"
                ",
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}