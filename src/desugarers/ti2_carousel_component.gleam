import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn nodemap(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, _, _, _) -> {
      // remove carousel buttons
      use <- infra.on_true_on_false(
        over: infra.v_has_key_value(vxml, "data-slide", "prev"),
        with_on_true: Ok(T(blame, [])),
      )
      use <- infra.on_true_on_false(
        over: infra.v_has_key_value(vxml, "data-slide", "next"),
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
        over: !{ infra.v_has_key_value(vxml, "class", "carousel") },
        with_on_true: Ok(vxml),
      )
      // vxml is node with carousel class
      // get only images from children
      let images = infra.descendants_with_tag(vxml, "img")

      let attributes =
        infra.on_true_on_false(
          over: infra.v_has_key_value(vxml, "id", "cyk-demo"),
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

fn nodemap_factory(_: InnerParam) -> n2t.OneToOneNodeMap {
  nodemap
}

fn desugarer_factory(inner: InnerParam) -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil
type InnerParam = Nil

const name = "ti2_carousel_component"
const constructor = ti2_carousel_component

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// converts Bootstrap carousel components to custom
/// Carousel components
pub fn ti2_carousel_component(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(Nil)),
    "
/// converts Bootstrap carousel components to custom
/// Carousel components
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