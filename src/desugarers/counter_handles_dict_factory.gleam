import blamedlines.{type Blame, Blame}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugarerDescription, DesugaringError,
}
import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, V}

pub type HandleInstances =
  Dict(String, #(String, String, String))

//   handle   local path, element id, string value
//   name     of page     on page     of handle

fn convert_handles_to_attributes(
  handles: HandleInstances,
) -> List(BlamedAttribute) {
  let blame = Blame("", 0, [])

  list.map2(dict.keys(handles), dict.values(handles), fn(key, values) {
    let #(id, filename, value) = values
    BlamedAttribute(
      blame: blame,
      key: "handle_" <> key,
      value: id <> " | " <> filename <> " | " <> value,
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
  // handles: HandleInstances,
) -> #(List(BlamedAttribute), List(#(String, String))) {
  let extracted_handles =
    list.filter(attributes, fn(att) { string.starts_with(att.key, "handle_") })
    |> list.map(fn(att) {
      let handle_name = string.drop_start(att.key, 7)
      #(handle_name, att.value)
    })

  let filtered_attributes =
    list.filter(attributes, fn(att) {
      !{ string.starts_with(att.key, "handle_") }
    })
  #(filtered_attributes, extracted_handles)
}

fn children_loop(children: List(VXML), handles: HandleInstances) {
  case children {
    [] -> Ok(#(children, handles))
    [first, ..rest] -> {
      use #(updated_child, updated_handles) <- result.try(
        handles_dict_factory_transform(first, handles, False),
      )
      use #(updated_children, updated_handles) <- result.try(children_loop(
        rest,
        updated_handles,
      ))
      Ok(#(list.flatten([[updated_child], updated_children]), updated_handles))
    }
  }
}

fn handles_dict_factory_transform(
  vxml: VXML,
  handles: HandleInstances,
  is_root: Bool,
) -> Result(#(VXML, HandleInstances), DesugaringError) {
  case vxml {
    V(b, t, attributes, children) -> {
      let #(attributes, extracted_handles) =
        attributes
        |> get_handles_from_attributes()

      use handles <- result.try(
        list.try_fold(extracted_handles, handles, fn(acc, handle) {
          let #(handle_name, att_value) = handle
          let assert [id, handle_value] = string.split(att_value, " | ")
          use _ <- result.try(check_handle_already_defined(handle_name, acc, b))
          Ok(dict.insert(acc, handle_name, #(id, b.filename, handle_value)))
        }),
      )

      use #(updated_children, updated_handles) <- result.try(children_loop(
        children,
        handles,
      ))

      case is_root {
        True -> {
          let handles_as_attributs =
            convert_handles_to_attributes(updated_handles)
          let updated_root = V(b, t, attributes, updated_children)
          let new_root =
            V(b, "GrandWrapper", handles_as_attributs, [updated_root])
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

pub fn handles_dict_factory_desugarer() -> Pipe {
  #(DesugarerDescription("Handles dictionary factory", None, "..."), fn(vxml) {
    use #(vxml, _) <- result.try(handles_dict_factory_transform(
      vxml,
      dict.new(),
      True,
    ))
    Ok(vxml)
  })
}
