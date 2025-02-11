import gleam/option
import gleam/list
import gleam/result
import gleam/string.{inspect as ins}
import blamedlines
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V, type BlamedAttribute, BlamedAttribute }

fn lookup_attributes_by_key(
  in: List(BlamedAttribute),
  key: String,
) -> Result(#(BlamedAttribute, List(BlamedAttribute)), Nil) {
  let #(matches, non_matches) = list.partition(in, fn (b) {b.key == key})
  let assert True = list.length(matches) <= 1
  case matches {
    [] -> Error(Nil)
    [unique] -> Ok(#(unique, non_matches))
    _ -> panic as "more than one match"
  }
}

fn maybe_semicolon(
  thing: String
) -> String {
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
        False -> Error(
          DesugaringError(
            existing.blame,
            "attribute of key '" <> key <> "' already exists in child (value '" <> value <> "' in parent)"
            )
          )
        True -> Ok([
          BlamedAttribute(
            existing.blame |> blamedlines.append_comment(blame |> ins),
            "style",
            existing.value <> maybe_semicolon(existing.value) <> value
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
  list.fold(
    attrs1,
    Ok(attrs2),
    fn (attrs, blamed_attribute) {
      case attrs {
        Error(e) -> Error(e)
        Ok(attrs) -> merge_one_attribute(attrs, blamed_attribute)
      }
    }
  )
}

fn param_transform(
  vxml: VXML, 
  extra: Extra
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case result.all(list.map(
        children,
        fn (child) {
          case child {
            T(_, _) -> Ok(child)
            V(child_blame, child_tag, child_attrs, grandchildren) -> {
              case list.contains(extra, #(tag, child_tag)) {
                False -> Ok(child)
                True -> {
                  case merge_attributes(attrs, child_attrs) {
                    Ok(child_attrs) -> Ok(V(child_blame, child_tag, child_attrs, grandchildren))
                    Error(d) -> Error(d)
                  }
                }
              }
            }
          }
        }
      )) {
        Ok(new_children) -> Ok(V(blame, tag, attrs, new_children))
        Error(e) -> Error(e)
      }
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeTransform {
  param_transform(_, extra)
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(#(String, String))
//********************************
//       parent, child
//********************************

pub fn merge_parent_attributes_into_child(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("merge_parent_attributes_into_child", option.Some(extra |> ins), "..."),
    desugarer_factory(extra),
  )
}
