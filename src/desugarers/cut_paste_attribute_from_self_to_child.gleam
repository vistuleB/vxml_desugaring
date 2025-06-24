import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V, type BlamedAttribute, BlamedAttribute}

fn update_child(children: List(VXML), child_tag: String, attribute: BlamedAttribute)
-> List(VXML) {
  children
  |> list.map(fn(child) {
    case child {
      V(b, t, attributes, sub_children) if t == child_tag -> {
        V(b, t, [attribute, ..attributes], sub_children)
      }
      V(b, t, a, sub_children) -> {
        V(b, t, a, update_child(sub_children, child_tag, attribute))
      }
      _ -> child
    }
  })
}

fn transform(
  node: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, child_tag, key) = inner
  case node {
    V(b, tag, attributes, children) if tag == parent_tag -> {
        case infra.v_attribute_with_key(node, key) {
          option.None -> Ok(node)
          option.Some(attribute) -> {
            let new_attribites = attributes |> list.filter(fn(x) {
              case x {
                BlamedAttribute(_, k, _) if k == key -> False
                _ -> True
              }
            })
            Ok(V(b, tag, new_attribites, update_child(children, child_tag, attribute)))
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

type Param =
  #(String, String, String)
//  ↖       ↖       ↖
//  parent  child   attribute
//  tag     tag     key

type InnerParam = Param

/// Moves an attribute with key `key` from the
/// first child of a node with tag `parent_tag`
/// to the node itself.
/// ```
/// #Param:
/// - parent tag
/// - child tag
/// - attribute key
/// ```
pub fn cut_paste_attribute_from_self_to_child(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "cut_paste_attribute_from_self_to_child",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// Moves an attribute with key `key` from the
/// first child of a node with tag `parent_tag`
/// to the node itself.
/// ```
/// #Param:
/// - parent tag
/// - child tag
/// - attribute key
/// ```
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
