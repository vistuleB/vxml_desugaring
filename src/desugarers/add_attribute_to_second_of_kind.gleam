import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn transform(
  node: VXML,
  _: List(VXML),
  previous_unmapped_siblings: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner_param: InnerParam,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, tag, attrs, children) -> {
      case tag == inner_param.0 {
        False -> Ok(node)
        True -> {
          case previous_unmapped_siblings {
            [V(_, prev_tag, _, _), ..] -> {
              case prev_tag == inner_param.0 {
                True ->
                  Ok(V(
                    blame,
                    tag,
                    [BlamedAttribute(blame, inner_param.1, inner_param.2), ..attrs],
                    children,
                  ))
                False -> Ok(node)
              }
            }
            _ -> Ok(node)
          }
        }
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeFancyTransform {
  fn(node, ancestors, prev_siblings, next_siblings, all_siblings) {
    transform(node, ancestors, prev_siblings, next_siblings, all_siblings, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)

type InnerParam = Param

/// Adds the specified attribute-value pair to nodes with the given tag name
/// when the previous sibling is also a node with the same tag name
pub fn add_attribute_to_second_of_kind(param: #(String, String, String)) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "add_attribute_to_second_of_kind",
      stringified_param: option.Some(param.0 <> " " <> param.1 <> "=" <> param.2),
      general_description: "
/// Adds the specified attribute-value pair to nodes with the given tag name
/// when the previous sibling is also a node with the same tag name
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}