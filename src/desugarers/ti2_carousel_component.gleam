import gleam/option.{None}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn param_transform(vxml: VXML) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, _, _, _) -> {
      // remove carousel buttons
      use <- infra.on_true_on_false(
        over: infra.has_attribute(vxml, "data-slide", "prev"),
        with_on_true: Ok(T(blame, [])),
      )
      use <- infra.on_true_on_false(
        over: infra.has_attribute(vxml, "data-slide", "next"),
        with_on_true: Ok(T(blame, [])),
      )
      infra.get_attribute_by_name(vxml, "data-slide-to")
      use <- infra.on_true_on_false(
        over: infra.get_attribute_by_name(vxml, "data-slide-to")
          |> option.is_some,
        with_on_true: Ok(T(blame, [])),
      )
      // carousel 
      use <- infra.on_true_on_false(
        over: !{ infra.has_attribute(vxml, "class", "carousel") },
        with_on_true: Ok(vxml),
      )
      // vxml is node with carousel class
      // get only images from children
      let images = infra.descendants_with_tag(vxml, "img")

      let attributes =
        infra.on_true_on_false(
          over: infra.has_attribute(vxml, "id", "cyk-demo"),
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

fn transform_factory() -> infra.NodeToNodeTransform {
  param_transform
}

fn desugarer_factory() -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory())
}

pub fn ti2_carousel_component() -> Pipe {
  Pipe(
    description: DesugarerDescription("ti2_carousel_component", None, "..."),
    desugarer: desugarer_factory(),
  )
}
