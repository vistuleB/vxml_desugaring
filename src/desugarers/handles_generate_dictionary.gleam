import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe} as infra
import vxml.{type BlamedAttribute, type VXML, BlamedAttribute, V}

type HandleInstances =
  Dict(String, #(String, String, String))

//   handle   local path, element id, string value
//   name     of page     on page     of handle

fn convert_handles_to_attributes(
  handles: HandleInstances,
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
  handles: HandleInstances,
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

fn children_loop(
  children: List(VXML),
  handles: HandleInstances,
  param: InnerParam,
  local_path: String,
) {
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

fn update_local_path(
  node: VXML,
  param: InnerParam,
  local_path: String,
) -> Result(String, DesugaringError) {
  let assert V(b, t, attributes, _) = node
  case
    list.find(param, fn(e) {
      let #(tag, _) = e
      tag == t
    })
  {
    Ok(#(_, att_key)) -> {
      case attributes |> list.find(fn(att) { att.key == att_key }) {
        Ok(BlamedAttribute(_, _, value)) -> Ok(value)
        Error(_) ->
          Error(DesugaringError(
            b,
            "Attribute " <> att_key <> " not found for node " <> t,
          ))
      }
    }
    Error(_) -> Ok(local_path)
  }
}

fn handles_dict_factory_transform(
  vxml: VXML,
  handles: HandleInstances,
  is_root: Bool,
  param: InnerParam,
  local_path: String,
) -> Result(#(VXML, HandleInstances), DesugaringError) {
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  fn(vxml) {
    use #(vxml, _) <- result.try(handles_dict_factory_transform(
      vxml,
      dict.new(),
      True,
      param,
      "",
    ))
    Ok(vxml)
  }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String, String))

//        ^        ^
//  tags to      attribute key
//  get local    that mentions
//  path from    local path

type InnerParam = Param

pub fn handles_generate_dictionary(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "handles_generate_dictionary",
      None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
