import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, _, _, _) -> {
      // remove carousel buttons
      use <- infra.on_true_on_false(
        over: infra.v_has_key_value_attribute(vxml, "data-slide", "prev"),
        with_on_true: Ok(T(blame, [])),
      )
      use <- infra.on_true_on_false(
        over: infra.v_has_key_value_attribute(vxml, "data-slide", "next"),
        with_on_true: Ok(T(blame, [])),
      )
      infra.v_attribute_with_key(vxml, "data-slide-to")
      use <- infra.on_true_on_false(
        over: infra.v_attribute_with_key(vxml, "data-slide-to")
          |> option.is_some,
        with_on_true: Ok(T(blame, [])),
      )
      // carousel
      use <- infra.on_true_on_false(
        over: !{ infra.v_has_key_value_attribute(vxml, "class", "carousel") },
        with_on_true: Ok(vxml),
      )
      // vxml is node with carousel class
      // get only images from children
      let images = infra.descendants_with_tag(vxml, "img")

      let attributes =
        infra.on_true_on_false(
          over: infra.v_has_key_value_attribute(vxml, "id", "cyk-demo"),
          with_on_true: [
            vxml.BlamedAttribute(blame, "jumpToLast", "true"),
          ],
          with_on_false: fn() { [] },
        )
      let carousel_node = V(blame, "Carousel", attributes, images)
      Ok(carousel_node)
    }
    _ -> Ok(vxml)
  }
}

fn transform_factory(_: InnerParam) -> infra.NodeToNodeTransform {
  transform
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

/// converts Bootstrap carousel components to custom Carousel components
pub fn ti2_carousel_component() -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "ti2_carousel_component",
      stringified_param: option.Some(ins(Nil)),
      general_description: "/// converts Bootstrap carousel components to custom Carousel components",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}