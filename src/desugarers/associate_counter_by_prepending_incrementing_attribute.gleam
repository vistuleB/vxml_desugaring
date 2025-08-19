import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, type TrafficLight, Continue} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, type BlamedAttribute, BlamedAttribute, V}
import blamedlines as bl

const desugarer_blame = bl.Des([], "associate_counter_by_...")

fn nodemap(
  vxml: VXML,
  inner: InnerParam,
) -> #(VXML, TrafficLight) {
  case vxml {
    V(blame, tag, old_attributes, children) if tag == inner.0 -> {
      let #(
        unassigned_handle_attributes,
        other_attributes,
      ) = list.partition(
        old_attributes,
        fn(attr) { attr.key == "handle" && string.split(attr.value, " ") |> list.length == 1 }
      )

      let handles_str =
        unassigned_handle_attributes
        |> list.map(fn(attr) { attr.value <> "<<" })
        |> string.join("")

      let new_attribute = BlamedAttribute(
        ..inner.2, 
        value: inner.1 <> " " <> handles_str <> inner.2.value,
      )

      #(
        V(
          blame,
          tag,
          [new_attribute, ..other_attributes],
          children,
        ),
        inner.3
      )
    }
    _ -> #(vxml, Continue)
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.EarlyReturnOneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.early_return_one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  #(
    param.0,
    param.1,
    BlamedAttribute(
      desugarer_blame,
      ".",
      "::++" <> param.1,
    ),
    param.2
  )
  |> Ok
}

type Param = #(String, String, TrafficLight)
//             ↖       ↖        ↖
//             tag     counter   traffic_light
type InnerParam = #(String, String, BlamedAttribute, TrafficLight)

const name = "associate_counter_by_prepending_incrementing_attribute"
const constructor = associate_counter_by_prepending_incrementing_attribute

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Given arguments
/// ```
/// tag_name, counter_name, traffic_light
/// ```
/// this desugarer adds an attribute of the form
/// ```
/// .=counter_name ::++counter_name
/// ```
/// to each node of tag 'tag', where the key is
/// a period '.' and the value is the string 
/// '<counter_name> ::++<counter_name>'. Because
/// counters are evaluated and substitued also
/// inside of key-value pairs, adding this 
/// key-value pair causes the counter <counter_name>
/// to increment at each occurrence of a node
/// of tag 'tag'.
/// 
/// Also assigns unassigned handles of the attribute
/// list of node 'tag' to the post-incremented value 
/// counter counter_name.
/// 
/// The traffic_light parameter determines whether to
/// Continue or GoBack after processing each node.
pub fn associate_counter_by_prepending_incrementing_attribute(
  param: Param,
) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// Given arguments
/// ```
/// tag_name, counter_name, traffic_light
/// ```
/// this desugarer adds an attribute of the form
/// ```
/// .=counter_name ::++counter_name
/// ```
/// to each node of tag 'tag', where the key is
/// a period '.' and the value is the string 
/// '<counter_name> ::++<counter_name>'. Because
/// counters are evaluated and substitued also
/// inside of key-value pairs, adding this 
/// key-value pair causes the counter <counter_name>
/// to increment at each occurrence of a node
/// of tag 'tag'.
/// 
/// Also assigns unassigned handles of the attribute
/// list of node 'tag' to the post-incremented value 
/// counter counter_name.
/// 
/// The traffic_light parameter determines whether to
/// Continue or GoBack after processing each node.
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