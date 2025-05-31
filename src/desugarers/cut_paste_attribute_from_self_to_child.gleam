import gleam/list
import gleam/option.{Some, None}
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
  param: InnerParam
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, child_tag, key) = param
  case node {
    V(b, tag, attributes, children) if tag == parent_tag -> {


        case infra.get_attribute_by_name(node, key) {
          None -> Ok(node)
          Some(attribute) -> {
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
    transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = #(String, String, String)
type InnerParam = Param

/// Moves an attribute with key `key` from the first child of a node with tag
/// `parent_tag` to the node itself.
/// #Param
/// - `parent tag` -
/// - `child tag` -
/// - `attribute key` -
pub fn cut_paste_attribute_from_self_to_child(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "cut_paste_attribute_from_self_to_child",
      Some(ins(param)),
      "Moves an attribute with key `key` from parent to a child.",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
