import blamedlines.{type Blame}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn generate_id(blame: Blame) -> String {
  "_"
  <> string.inspect(int.random(9999))
  <> string.inspect(blame.line_no)
  <> string.inspect(int.random(9999))
}

fn transform(node: VXML) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(b, t, attributes, c) -> {
      let id = generate_id(b)

      let has_handles =
        list.filter(attributes, fn(att) {
          string.starts_with(att.key, "handle")
        })

      let attributes =
        attributes
        |> list.index_map(fn(att, _) {
          case string.starts_with(att.key, "handle") {
            True -> {
              use #(handle_name, handle_value) <- infra.on_error_on_ok(
                string.split_once(att.value, " "),
                fn(_) {
                  // early return if we can't split the attribute value
                  BlamedAttribute(..att, value: att.value <> " | " <> id <> " | " <> "")
                }
              )
              BlamedAttribute(..att, value: handle_name <> " | " <> id <> " | " <> handle_value)
            }
            False -> att
          }
        })

      let id_attribute = case list.is_empty(has_handles), infra.get_attribute_by_name(node, "id") {
        False, None -> [BlamedAttribute(b, key: "id", value: id)]
        False, Some(id_attribute) -> [id_attribute]
        _, _ -> []
      }

      Ok(V(b, t, list.flatten([attributes, id_attribute]), c))
    }
  }
}

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

/// Generates a unique ID and
/// filters attributes to find
/// any that start with "handle"
/// in which their values are expected
/// to be in the format: handle_name handle_value
/// It does the following two things:
/// 1- Processes these "handle" attributes values by:
///  . Splitting their values on space
///  . Reformatting them to include the 
///    generated ID in the format: 
///    handle_name | id | handle_value
///    or  just value | id 
///    if the value is not splitable,
///  
/// 2- Add id attribute to the node
///    ( usefull for html href link ?id=x )

/// Returns a new V node with the transformed attributes
pub fn handles_generate_ids() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "handles_generate_ids",
      option.None,
      "
Generates a unique ID and
filters attributes to find
any that start with \"handle\"
in which their values are expected
to be in the format: handle_name handle_value
It does the following two things:
1- Processes these \"handle\" attributes values by:
 . Splitting their values on space
 . Reformatting them to include the 
   generated ID in the format: 
   handle_name | id | handle_value
   or  just value | id 
   if the value is not splitable,
 
2- Add id attribute to the node
   ( usefull for html href link ?id=x )
",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
