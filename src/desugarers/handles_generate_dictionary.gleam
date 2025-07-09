import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some, None}
import gleam/result
import gleam/string
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, V}

type HandlesDict =
  Dict(String, #(String,     String,     String))
//     handle    local path  element id  string value
//     name      of page     on page     of handle

type State = #(HandlesDict, String)

fn convert_handles_to_attributes(
  handles: HandlesDict,
) -> List(BlamedAttribute) {
  let blame = Blame("", 0, 0, [])
  list.map2(
    dict.keys(handles),
    dict.values(handles),
    fn (key, values) {
      let #(id, filename, value) = values
      BlamedAttribute(
        blame: blame,
        key: "handle",
        value: key <> " | " <> id <> " | " <> filename <> " | " <> value,
      )
    }
  )
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
    attributes
    |> list.partition(fn(att) {att.key == "handle"})

  let extracted_handles =
    handle_attributes
    |> list.map(fn(att) {
      let assert [handle_name, id, value] = string.split(att.value, " | ")
      #(handle_name, id, value)
    })

  #(filtered_attributes, extracted_handles)
}

fn update_local_path(
  node: VXML,
  param: InnerParam,
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

fn t_transform(
  vxml: VXML,
  state: State,
) -> Result(#(VXML, State), DesugaringError) {
  Ok(#(vxml, state))
}

fn v_before_transforming_children(
  vxml: VXML,
  state: State,
  inner: InnerParam,
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(b, t, attributes, c) = vxml
  let #(handles, local_path) = state
  use local_path <- result.try(update_local_path(vxml, inner, local_path))
  let #(attributes, extracted_handles) = get_handles_from_attributes(attributes)

  use handles <- result.try(
    list.try_fold(extracted_handles, handles, fn(acc, handle) {
      let #(handle_name, id, handle_value) = handle
      use _ <- result.try(check_handle_already_defined(handle_name, acc, b))
      Ok(dict.insert(acc, handle_name, #(id, local_path, handle_value)))
    }),
  )

  Ok(#(V(b, t, attributes, c), #(handles, local_path)))
}

fn v_after_transforming_children(
  vxml: VXML,
  ancestors: List(VXML),
  state: State,
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(b, _, _, _) = vxml
  let #(handles, _) = state

  case list.is_empty(ancestors) {
    False -> Ok(#(vxml, state))
    True -> {
      let handles_as_attributes = convert_handles_to_attributes(handles)
      let grand_wrapper = V(b, "GrandWrapper", handles_as_attributes, [vxml])
      Ok(#(grand_wrapper, state))
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.StatefulDownAndUpNodeToNodeFancyTransform(State) {
   infra.StatefulDownAndUpNodeToNodeFancyTransform(
    v_before_transforming_children: fn(vxml, _, _, _, _, state) {
      v_before_transforming_children(vxml, state, inner)
    },
    v_after_transforming_children: fn(vxml, ancestors, _, _, _, _, state) {
      v_after_transforming_children(vxml, ancestors, state)
    },
    t_transform: fn(vxml, _, _, _, _, state) {
      t_transform(vxml, state)
    },
  )
}

fn desugarer_factory(inner: InnerParam) -> infra.DesugarerTransform {
  infra.stateful_down_up_fancy_node_to_node_desugarer_factory(
    transform_factory(inner),
    #(dict.new(), "")
  )
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,     String))
//       ↖           ↖
//       tags to     key of attribute
//       get local   holding the
//       path from   local path

type InnerParam = Param

const name = "handles_generate_dictionary"
const constructor = handles_generate_dictionary

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Looks for `handle` attributes in the V nodes
/// and transforms which are expected to be in form:
/// `handle | id | value`. (Panics if not in this 
/// form.)
/// 
/// Transform the values into a dict where the key 
/// is the handle name and the values are tuples 
/// #(String, String, String) comprising the handle, 
/// id, and value.
/// 
/// Adds new field of data (path) which represents 
/// the filename and is expected to be available
/// In attribute value of node with Param.0 tag 
/// Param.1 attribute_key.
/// 
/// Wraps the document root by a V node with tag 
/// GrandWrapper and transform back the dict as the
/// grandwrapper's attributes.
/// 
/// Returns a pair of newly created node and state 
/// of handles used to check for name uniqueness.
/// 
/// Throws error if
/// 1. there are multiple handles with same 
///    handle_name
/// 2. no node found with Param.0 tag Param.1 
///    attribute_key
pub fn handles_generate_dictionary(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// Looks for `handle` attributes in the V nodes
/// and transforms which are expected to be in form:
/// `handle | id | value`. (Panics if not in this 
/// form.)
/// 
/// Transform the values into a dict where the key 
/// is the handle name and the values are tuples 
/// #(String, String, String) comprising the handle, 
/// id, and value.
/// 
/// Adds new field of data (path) which represents 
/// the filename and is expected to be available
/// In attribute value of node with Param.0 tag 
/// Param.1 attribute_key.
/// 
/// Wraps the document root by a V node with tag 
/// GrandWrapper and transform back the dict as the
/// grandwrapper's attributes.
/// 
/// Returns a pair of newly created node and state 
/// of handles used to check for name uniqueness.
/// 
/// Throws error if
/// 1. there are multiple handles with same 
///    handle_name
/// 2. no node found with Param.0 tag Param.1 
///    attribute_key
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    },
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}