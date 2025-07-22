import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, type BlamedAttribute, BlamedAttribute, V}

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> VXML {
  case vxml {
    V(blame, tag, old_attributes, children) if tag == inner.0 -> {
      let #(
        unassigned_handle_attributes,
        other_attributes
      ) = list.partition(old_attributes, fn(attr) {
        let assert True = attr.value == string.trim(attr.value)
        attr.key == "handle"
        && string.split(attr.value, " ") |> list.length == 1
      })

      let handles_str =
        unassigned_handle_attributes
        |> list.map(fn(attr) { attr.value <> "<<" })
        |> string.join("")

      let new_attribute = BlamedAttribute(
        ..inner.2, 
        value: inner.1 <> " " <> handles_str <> inner.2.value,
      )

      V(
        blame,
        tag,
        [new_attribute, ..other_attributes],
        children,
      )
    }
    _ -> vxml
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_no_error_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  #(
    param.0,
    param.1,
    BlamedAttribute(
      infra.blame_us("assoc_counter_no_list"),
      ".",
      "::++" <> param.1,
    )
  )
  |> Ok
}

type Param = #(String, String)
//             ↖       ↖
//             tag     counter_name
type InnerParam = #(String, String, BlamedAttribute)

const name = "associate_counter_by_prepending_incrementing_attribute_no_list"
const constructor = associate_counter_by_prepending_incrementing_attribute_no_list

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
pub fn associate_counter_by_prepending_incrementing_attribute_no_list(
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