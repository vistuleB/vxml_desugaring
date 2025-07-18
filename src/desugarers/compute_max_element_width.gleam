import gleam/result
import gleam/float
import gleam/list
import gleam/int
import gleam/option.{Some, None}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugaringError, DesugaringError, type DesugarerTransform} as infra
import vxml.{type VXML, BlamedAttribute, T, V}
import nodemaps_2_desugarer_transforms as n2t

fn v_before_transforming_children(
  node: VXML,
  state: Float,
  inner: InnerParam,
) -> Result(#(VXML, Float), DesugaringError) {
  let assert V(blame, tag, _, _) = node
  case list.contains(inner, tag) {
    False -> Ok(#(node, state))
    True -> {
      case infra.v_attribute_with_key(node, "width") {
        None -> Error(DesugaringError(blame, tag <> " tag must have width attribute"))
        Some(attr) -> {
          use width_str <- infra.on_none_on_some(
            over: infra.take_digits(attr.value),
            with_on_none: Error(DesugaringError(attr.blame, "Could not find digits in width attribute"))
          )
          use parsed_width <- result.try(
            case float.parse(width_str), int.parse(width_str) {
              Ok(width), _ -> Ok(width)
              _, Ok(width) -> Ok(int.to_float(width))
              _, _ -> Error(DesugaringError(attr.blame, "Could not parse width attribute as number"))
            }
          )

          Ok(#(node, float.max(state, parsed_width)))
        }
      }
    }
  }
}

fn v_after_transforming_children(
  node: VXML,
  _: Float,
  state: Float,
) -> Result(#(VXML, Float), DesugaringError) {
  let assert V(_, tag, _, _) = node
  case tag == "Chapter" || tag == "Bootcamp" {
    False -> Ok(#(node, state))
    True -> {
      Ok(#(
        V(
          ..node,
          attributes: [
            BlamedAttribute(node.blame, "max-element-width", ins(state)),
            ..node.attributes
          ]
        ),
        0. // reset state for next article
      ))
    }
  }
}

fn nodemap_factory(inner_param: InnerParam) -> n2t.OneToOneBeforeAndAfterStatefulNodeMap(Float) {
   n2t.OneToOneBeforeAndAfterStatefulNodeMap(
    v_before_transforming_children: fn(node, state){
      v_before_transforming_children(node, state, inner_param)
    },
    v_after_transforming_children: v_after_transforming_children,
    t_nodemap: fn(node, state) {
      let assert T(_, _) = node
      Ok(#(node, state))
    },
  )
}

fn transform_factory(inner_param: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_before_and_after_stateful_nodemap_2_desugarer_transform(nodemap_factory(inner_param), 0.)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = List(String)
//             ↖
//           tags to include in the max width calculation

type InnerParam = List(String)

const name = "compute_max_element_width"
const constructor = compute_max_element_width

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// compute max element width
pub fn compute_max_element_width(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "
/// compute max element width
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner_param) -> transform_factory(inner_param)
    }
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