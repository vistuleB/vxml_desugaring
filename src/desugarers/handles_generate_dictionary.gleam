import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some, None}
import gleam/result
import gleam/pair
import gleam/string
import infrastructure.{type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, V}

type HandlesDict =
  Dict(String, #(String,     String,     String))
//     handle    local path  element id  string value
//     name      of page     on page     of handle

fn convert_handles_to_attributes(
  handles: HandlesDict,
) -> List(BlamedAttribute) {
  let blame = Blame("", 0, 0, [])

  list.map2(dict.keys(handles), dict.values(handles), fn(key, values) {
    let #(id, filename, value) = values
    BlamedAttribute(
      blame: blame,
      key: "handle",
      value: key <> " | " <> id <> " | " <> filename <> " | " <> value,
    )
  })
}

fn check_handle_already_defined(
  new_handle_name: String,
  handles: HandlesDict,
  blame: Blame,
) -> Result(Nil, DesugaringError) {
  case dict.get(handles, new_handle_name) {
    Ok(_) ->
      Error(DesugaringError(
        blame: blame,
        message: "Handle " <> new_handle_name <> " has already been used",
      ))
    Error(_) -> Ok(Nil)
  }
}

fn get_handles_from_attributes(
  attributes: List(BlamedAttribute),
) -> #(List(BlamedAttribute), List(#(String, String, String))) {

  let #(handle_attributes, filtered_attributes) =
    list.partition(attributes, fn(att) {
      att.key == "handle"
    })

  let extracted_handles =
    list.map(handle_attributes, fn(att) {
      let assert [handle_name, id, value] = string.split(att.value, " | ")
      #(handle_name, id, value)
    })

  #(filtered_attributes, extracted_handles)
}

fn update_local_path(
  node: VXML,
  param: Param,
  local_path: String,
) -> Result(String, DesugaringError) {
  let assert V(_, _, _, _) = node

  case infra.use_list_pair_as_dict(param, node.tag) {
    Ok(att_key) -> {
      case infra.v_attribute_with_key(node, att_key) {
        Some(BlamedAttribute(_, _, value)) -> Ok(value)
        None -> Error(DesugaringError(node.blame, "attribute " <> att_key <> " not found for node " <> node.tag))
      }
    }
    Error(_) -> Ok(local_path)
  }
}

fn children_loop(
  children: List(VXML),
  handles: HandlesDict,
  param: Param,
  local_path: String,
) -> Result(#(List(VXML), HandlesDict), DesugaringError) {
  case children {
    [] -> Ok(#(children, handles))
    [first, ..rest] -> {
      use #(updated_child, updated_handles) <- result.try(
        handles_dict_factory_transform(first, handles, False, param, local_path),
      )
      use #(updated_children, updated_handles) <- result.try(children_loop(
        rest,
        updated_handles,
        param,
        local_path,
      ))
      Ok(#(list.flatten([[updated_child], updated_children]), updated_handles))
    }
  }
}

fn handles_dict_factory_transform(
  vxml: VXML,
  handles: HandlesDict,
  is_root: Bool,
  param: Param,
  local_path: String,
) -> Result(#(VXML, HandlesDict), DesugaringError) {
  case vxml {
    V(b, t, attributes, children) -> {
      // check local path in param list
      use local_path <- result.try(update_local_path(vxml, param, local_path))

      let #(attributes, extracted_handles) =
        attributes
        |> get_handles_from_attributes()

      use handles <- result.try(
        list.try_fold(extracted_handles, handles, fn(acc, handle) {
          let #(handle_name, id, handle_value) = handle
          use _ <- result.try(check_handle_already_defined(handle_name, acc, b))
          Ok(dict.insert(acc, handle_name, #(id, local_path, handle_value)))
        }),
      )

      use #(updated_children, updated_handles) <- result.try(children_loop(
        children,
        handles,
        param,
        local_path,
      ))

      case is_root {
        True -> {
          let handles_as_attributes =
            convert_handles_to_attributes(updated_handles)
          let updated_root = V(b, t, attributes, updated_children)
          let new_root =
            V(b, "GrandWrapper", handles_as_attributes, [updated_root])
          Ok(#(new_root, updated_handles))
        }
        False -> {
          Ok(#(V(b, t, attributes, updated_children), updated_handles))
        }
      }
    }

    _ -> Ok(#(vxml, handles))
  }
}

type Param =
  List(#(String, String))
//        ^        ^
//  tags to      attribute key
//  get local    that mentions
//  path from    local path

/// Looks for `handle` attributes 
/// in the V nodes and transforms
/// which are expected to be in form:
/// `handle | id | value`.
/// ( panics if not in this form )
/// 
/// Transform the values into a dict
/// where the key is the handle name
/// and the values are tuples 
/// #(String, String, String) comprising
/// the handle, id, and value.
/// 
/// Adds new field of data (path)
/// which represents the filename
/// and is expected to be available
/// In attribute value of node with
/// Param.0 tag Param.1 attribute_key.
/// 
/// Wraps the document root by a V
/// node with tag GrandWrapper
/// and transform back the dict as the
/// grandwrapper's attributes.
/// 
/// Returns a pair of newly created
/// node and state of handles used
/// to check for name uniqueness.
/// 
/// Throws error if
/// 1. there are multiple handles
///    with same handle_name
/// 2. no node found with Param.0 tag Param.1 attribute_key
pub fn handles_generate_dictionary(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "handles_generate_dictionary",
      None,
      "...",
    ),
    desugarer: fn(vxml) {
      result.map(
        handles_dict_factory_transform(vxml, dict.new(), True, param, ""),
        pair.first
      )
    },
  )
}
