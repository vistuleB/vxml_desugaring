import gleam/result
import gleam/float
import gleam/int
import gleam/option.{Some, None}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError,DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

fn compare_widths_based_on_tag(tag: String, state: State, width: Float) -> State {
  let #(largest_centered_image_width, largest_side_image_width) = state

  case tag  {
    "Image" -> #(float.max(largest_centered_image_width, width), largest_side_image_width)
    "ImageLeft" | "ImageRight"-> 
      #(largest_centered_image_width, float.max(largest_side_image_width, width))
    _ -> panic as "No way"
  }
}

fn v_before_transforming_children(
  node: VXML,
  state: State,
) -> Result(#(VXML, State), DesugaringError) {
  let assert V(blame, tag, _, _) = node
  case tag == "ImageLeft" || tag == "ImageRight" || tag == "Image" {
    False -> Ok(#(node, state))
    True -> {
      case infra.v_attribute_with_key(node, "width") {
        None -> Error(DesugaringError(blame, "Image tag must have width attribute"))
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

          Ok(#(node, compare_widths_based_on_tag(tag, state, parsed_width)))
        }
      }
    }
  }
}

fn v_after_transforming_children(
  node: VXML,
  _: State,
  state: State,
) -> Result(#(VXML, State), DesugaringError) {
  let #(largest_centered_image_width, largest_side_image_width) = state
  let assert V(_, tag, _, _) = node
  case tag == "Chapter" || tag == "Bootcamp" {
    False -> Ok(#(node, state))
    True -> {
      Ok(#(
        V(
          ..node,
          attributes: [
            BlamedAttribute(node.blame, "largest_centered_image_width", ins(largest_centered_image_width)),
            BlamedAttribute(node.blame, "largest_side_image_width", ins(largest_side_image_width)),
            ..node.attributes]
        ),
        #(0., 0.)
      ))
    }
  }
}

type State = #(Float, Float)

fn transform_factory(_: InnerParam) -> infra.StatefulDownAndUpNodeToNodeTransform(State) {
  infra.StatefulDownAndUpNodeToNodeTransform(
    v_before_transforming_children: v_before_transforming_children,
    v_after_transforming_children: v_after_transforming_children,
    t_transform: fn(node, state) {
      let assert T(_, _) = node
      Ok(#(node, state))
    },
  )
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.stateful_down_up_node_to_node_desugarer_factory(transform_factory(inner), #(0., 0.))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil


pub fn find_out_largest_image_in_chapter() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "find_out_largest_image_in_chapter",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
