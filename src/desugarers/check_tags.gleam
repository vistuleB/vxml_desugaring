import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}
import blamedlines

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(approved_tags, identifier) = inner
  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, tag, _, _) -> {
      case list.contains(approved_tags, tag) {
        True -> Ok(vxml)
        False -> Error(DesugaringError(
          blamedlines.Blame(identifier, 0, 0, []),
          "Tag '" <> tag <> "' is not in the approved list. Approved tags: " <> ins(approved_tags)
        ))
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let #(approved_tags, identifier) = param
  case approved_tags {
    [] -> Error(DesugaringError(blamedlines.Blame(identifier, 0, 0, []), "Approved tags list cannot be empty"))
    _ -> Ok(param)
  }
}

type Param = #(List(String), String)
//             ↖            ↖
//             approved tags id
type InnerParam = Param

const name = "check_tags"
const constructor = check_tags

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Validates that all tags in the document are
/// from an approved list of tags.
///
/// Returns a DesugaringError if any tag is found
/// that is not in the approved list.
///
/// Processes all nodes depth-first.
pub fn check_tags(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// Validates that all tags in the document are
/// from an approved list of tags.
///
/// Returns a DesugaringError if any tag is found
/// that is not in the approved list.
///
/// Processes all nodes depth-first.
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
      param: #(["root", "div", "p", "span"], "test1"),
      source:   "
                <> root
                  <> div
                    <> p
                      <>
                        \"Hello\"
                    <> span
                      <>
                        \"World\"
                ",
      expected: "
                <> root
                  <> div
                    <> p
                      <>
                        \"Hello\"
                    <> span
                      <>
                        \"World\"
                ",
    ),
    infra.AssertiveTestData(
      param: #(["root", "section", "h1"], "test2"),
      source:   "
                <> root
                  <> section
                    <> h1
                      <>
                        \"Title\"
                ",
      expected: "
                <> root
                  <> section
                    <> h1
                      <>
                        \"Title\"
                ",
    ),
  ]
}

// Note: Error testing infrastructure is not available,
// so we only include assertive tests for valid cases.
// Invalid cases would result in DesugaringError at runtime.

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}
