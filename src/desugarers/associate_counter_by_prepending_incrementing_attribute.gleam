import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, BlamedAttribute, T, V}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    T(_, _) -> vxml
    V(blame, tag, old_attributes, children) -> {
      case dict.get(inner, tag) {
        Ok(counter_names) -> {
          let #(unassigned_handle_attributes, other_attributes) =
            list.partition(old_attributes, fn(attr) {
              let assert True = attr.value == string.trim(attr.value)
              attr.key == "handle"
              && string.split(attr.value, " ") |> list.length == 1
            })

          let handles_str =
            unassigned_handle_attributes
            |> list.map(fn(attr) { attr.value <> "<<" })
            |> string.join("")

          let new_attributes =
            counter_names
            |> list.index_map(fn(counter_name, index) {
              case index == 0 {
                True ->
                  BlamedAttribute(
                    blame,
                    ".",
                    counter_name <> " " <> handles_str <> "::++" <> counter_name,
                  )
                False ->
                  BlamedAttribute(
                    blame,
                    ".",
                    counter_name <> " " <> "::++" <> counter_name,
                  )
              }
            })

          V(
            blame,
            tag,
            list.flatten([new_attributes, other_attributes]),
            children,
          )
        }
        Error(Nil) -> vxml
      }
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_no_error_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(infra.aggregate_on_first(param))
}

type Param =
  List(#(String, String))
//       ↖      ↖
//       tag    counter_name

type InnerParam =
  Dict(String, List(String))

const name = "associate_counter_by_prepending_incrementing_attribute"
const constructor = associate_counter_by_prepending_incrementing_attribute

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// For each #(tag, counter_name) pair in the 
/// parameter list, this desugarer adds an 
/// attribute of the form
/// ```
/// .=counter_name ::++counter_name
/// ```
/// to each node of tag 'tag', where the key is
/// a period '.' and the value is the string 
/// '<counter_name> ::++<counter_name>'. As 
/// counters are evaluated and substitued also
/// inside of key-value pairs, adding this 
/// key-value pair causes the counter <counter_name>
/// to increment at each occurrence of a node
/// of tag 'tag'. Also assigns unassigned 
/// handles of the attribute list of node 'tag'
/// to the first counter being incremented in
/// this fashion, by this desugarer.
pub fn associate_counter_by_prepending_incrementing_attribute(
  param: Param,
) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    "
/// For each #(tag, counter_name) pair in the 
/// parameter list, this desugarer adds an 
/// attribute of the form
/// ```
/// .=counter_name ::++counter_name
/// ```
/// to each node of tag 'tag', where the key is
/// a period '.' and the value is the string 
/// '<counter_name> ::++<counter_name>'. As 
/// counters are evaluated and substitued also
/// inside of key-value pairs, adding this 
/// key-value pair causes the counter <counter_name>
/// to increment at each occurrence of a node
/// of tag 'tag'. Also assigns unassigned 
/// handles of the attribute list of node 'tag'
/// to the first counter being incremented in
/// this fashion, by this desugarer.
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    },
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}