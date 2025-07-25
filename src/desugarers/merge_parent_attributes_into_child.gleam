import blamedlines
import gleam/list
import gleam/option
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type BlamedAttribute, BlamedAttribute, type VXML, T, V}

fn lookup_attributes_by_key(
  in: List(BlamedAttribute),
  key: String,
) -> Result(#(BlamedAttribute, List(BlamedAttribute)), Nil) {
  let #(matches, non_matches) = list.partition(in, fn(b) { b.key == key })
  let assert True = list.length(matches) <= 1
  case matches {
    [] -> Error(Nil)
    [unique] -> Ok(#(unique, non_matches))
    _ -> panic as "more than one match"
  }
}

fn maybe_semicolon(thing: String) -> String {
  case string.ends_with(thing, ";") {
    True -> ""
    False -> ";"
  }
}

fn merge_one_attribute(
  attrs: List(BlamedAttribute),
  to_merge: BlamedAttribute,
) -> Result(List(BlamedAttribute), DesugaringError) {
  let BlamedAttribute(blame, key, value) = to_merge
  let res = lookup_attributes_by_key(attrs, key)
  case res {
    Error(Nil) -> Ok([to_merge, ..attrs])
    Ok(#(existing, remaining)) -> {
      case key == "style" {
        False ->
          Error(DesugaringError(
            existing.blame,
            "attribute of key '"
              <> key
              <> "' already exists in child (value '"
              <> value
              <> "' in parent)",
          ))
        True ->
          Ok([
            BlamedAttribute(
              existing.blame |> blamedlines.append_comment(blame |> ins),
              "style",
              existing.value <> maybe_semicolon(existing.value) <> value,
            ),
            ..remaining
          ])
      }
    }
  }
}

fn merge_attributes(
  attrs1: List(BlamedAttribute),
  attrs2: List(BlamedAttribute),
) -> Result(List(BlamedAttribute), DesugaringError) {
  list.fold(attrs1, Ok(attrs2), fn(attrs, blamed_attribute) {
    case attrs {
      Error(e) -> Error(e)
      Ok(attrs) -> merge_one_attribute(attrs, blamed_attribute)
    }
  })
}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case
        result.all(
          list.map(children, fn(child) {
            case child {
              T(_, _) -> Ok(child)
              V(child_blame, child_tag, child_attrs, grandchildren) -> {
                case list.contains(inner, #(tag, child_tag)) {
                  False -> Ok(child)
                  True -> {
                    case merge_attributes(attrs, child_attrs) {
                      Ok(child_attrs) ->
                        Ok(V(child_blame, child_tag, child_attrs, grandchildren))
                      Error(d) -> Error(d)
                    }
                  }
                }
              }
            }
          }),
        )
      {
        Ok(new_children) -> Ok(V(blame, tag, attrs, new_children))
        Error(e) -> Error(e)
      }
    }
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

type Param =
  List(#(String, String))
//       ↖       ↖
//       parent  child

type InnerParam = Param

const name = "merge_parent_attributes_into_child"
const constructor = merge_parent_attributes_into_child

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// merges parent attributes into child elements for
/// specified parent-child tag pairs
pub fn merge_parent_attributes_into_child(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// merges parent attributes into child elements for
/// specified parent-child tag pairs
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
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}