import gleam/option
import gleam/string.{inspect as ins}
import gleam/list
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V, T}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, child_tag, descendant_tag) = inner
  case node {
    V(blame, tag, attrs, children) if tag == parent_tag -> {
      case children {
        [V(_, first_child_tag, _, _), ..] if first_child_tag == child_tag -> Ok(node)
        _ -> {
          // Find first descendant with the target tag
          case infra.descendants_with_tag(node, descendant_tag) |> list.first {
            Ok(descendant) -> {
              let descendant_children = infra.get_children(descendant)
              let new_child = V(
                blame,
                child_tag,
                [],
                descendant_children
              )
              Ok(V(blame, tag, attrs, [new_child, ..children]))
            }
            Error(_) -> {
              Ok(node)
            }
          }
        }
      }
    }
    _ -> Ok(node)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)
//            ↖       ↖       ↖
//            parent  child   descendant
//            tag     tag     tag

type InnerParam = Param

/// Auto-generates first child if missing from first descendant of type.
/// For each parent element, if it doesn't have a first child of the specified type,
/// creates one based on the contents of the first descendant of the specified type.
/// If no such descendant exists, does not create anything.
pub fn auto_generate_first_child_if_missing_from_first_descendant_of_type(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "auto_generate_first_child_if_missing_from_first_descendant_of_type",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// Auto-generates first child if missing from first descendant of type.
/// For each parent element, if it doesn't have a first child of the specified type,
/// creates one based on the contents of the first descendant of the specified type.
/// If no such descendant exists, does not create anything.
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
} 