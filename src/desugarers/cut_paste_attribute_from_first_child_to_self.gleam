import blamedlines
import gleam/result
import gleam/list
import gleam/option.{Some, type Option, None}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type VXML, V, type BlamedAttribute}

/// return option of
/// - Attribute with key `key`
/// - Modified children ( with removed attribute )
fn check_first_child(children: List(VXML), key: String)
-> Result(Option(#(BlamedAttribute, List(VXML))), DesugaringError) {

   use first_child <- result.try(list.first(children) |> result.map_error(fn(_) {
      DesugaringError(blamedlines.Blame("L20", 20, 0, []), "No first child found")
    }))

  case first_child {
    V(b, t, attributes, sub_children) -> {

      let attribute = list.find(attributes, fn(att) {
        att.key == key
      })

      case attribute {
        Error(_) -> {
          //  check_first_child(sub_children, key)
          use res <- result.try(check_first_child(sub_children, key))
          case res {
            None -> Ok(None)
            Some(#(att, new_sub_children)) -> {
              let assert [_, ..rest_children] = children
              let new_first_child = V(b, t, attributes, new_sub_children)
              Ok(Some(#(
                att,
                [new_first_child, ..rest_children]
              )))
            }
          }
        }
        Ok(att) -> {
          let assert [_, ..rest_children] = children
          let new_first_child = V(b, t, list.filter(attributes, fn(att) { att.key != key }), sub_children)

          Ok(Some(#(
            att,
            [new_first_child, ..rest_children]
          )))
        }
      }
    }
    _ -> Ok(None)
  }
}

fn transform(
  node: VXML,
  param: InnerParam
) -> Result(VXML, DesugaringError) {
  let #(parent_tag, key) = param
  case node {
    V(b, tag, original_attributes, children) if tag == parent_tag -> {

        use res <- result.try(check_first_child(children, key))
        case res {
          None -> Ok(node)
          Some(#(att, children)) ->  Ok(V(b, tag, [att, ..original_attributes], children))
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

type Param = #(String, String)

type InnerParam = Param

/// Moves an attribute with key `key` from the first child of a node with tag
/// `parent_tag` to the node itself.
/// #Param
/// - `parent tag` -
/// - `attribute key` -
pub fn cut_paste_attribute_from_first_child_to_self(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "cut_paste_attribute_from_first_child_to_self",
      Some(ins(param)),
      "Moves an attribute with key `key` from the first child of a node with tag `parent_tag` to the node itself.",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
