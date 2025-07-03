import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V, T}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      case dict.get(inner, tag) {
        Error(Nil) -> Ok(vxml)
        Ok(new_tag_info) -> {
          let #(new_tag, new_attrs) = new_tag_info
          let new_attributes = list.append(attrs, new_attrs)
          Ok(V(blame, new_tag, new_attributes, children))
        }
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let inner_param = param
    |> list.map(fn(renaming: #(String, String, List(#(String, String)))) {
      let #(old_tag, new_tag, attrs) = renaming
      let attrs_converted = list.map(attrs, fn(attr) {
        let #(key, value) = attr
        vxml.BlamedAttribute(infra.blame_us(desugarer_name), key, value)
      })
      #(old_tag, #(new_tag, attrs_converted))
    })
    |> dict.from_list
  Ok(inner_param)
}

type Param =
  List(#(String, String, List(#(String, String))))
//       ↖       ↖       ↖
//       old_tag new_tag list of attributes as key value pairs

type InnerParam =
  Dict(String, #(String, List(vxml.BlamedAttribute)))

pub const desugarer_name = "rename_with_attributes"
pub const desugarer_pipe = rename_with_attributes

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------
/// renames tags and adds attributes to them
pub fn rename_with_attributes(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// renames tags and adds attributes to them
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}