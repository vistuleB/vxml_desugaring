import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {

      use inner_dict <- infra.on_error_on_ok(
        dict.get(inner, tag),
        fn(_) {
          Ok(vxml)
        },
      )
    
      let new_children =
        list.map(children, fn(child) {
          use child_blame, child_tag, child_attrs, grandchildren <- infra.on_t_on_v(child, fn(_, _){
            child
          })
          case dict.get(inner_dict, child_tag) {
            Error(Nil) -> child
            Ok(new_name) ->
              V(child_blame, new_name, child_attrs, grandchildren)
          }
        })

      Ok(V(blame, tag, attrs, new_children))
    }
  }
}

fn transform_factory(inner: InnerParam) -> n2t.OneToOneNodeMap {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let inner_param = param
    |> list.fold(
      from: dict.from_list([]),
      with: fn(
        state: Dict(String, Dict(String, String)),
        incoming: #(String, String, String),
      ) {
        let #(old_name, new_name, parent_name) = incoming
        case dict.get(state, parent_name) {
          Error(Nil) -> {
            dict.insert(
              state,
              parent_name,
              dict.from_list([#(old_name, new_name)]),
            )
          }
          Ok(existing_dict) -> {
            dict.insert(
              state,
              parent_name,
              dict.insert(existing_dict, old_name, new_name),
            )
          }
        }
      },
    )
  Ok(inner_param)
}

type Param =
  List(#(String,   String,   String))
//       ↖        ↖         ↖
//       old_name new_name   parent

type InnerParam =
  Dict(String, Dict(String, String))

const name = "rename_when_child_of"
const constructor = rename_when_child_of

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// renames tags when they are children of specified parent tags
pub fn rename_when_child_of(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// renames tags when they are children of specified parent tags
    ",
    case param_to_inner_param(param) {
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
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}