import gleam/list
import gleam/option.{None}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn nodemap(
  vxml: VXML,
) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) if tag == "Carousel" -> {
      case children {
        [] -> {
          // get all src attributes
          let src_attrs = list.filter(attrs, fn(attr) { attr.key == "src" })
          // create CarouselItem children with img tags
          let carousel_items = list.map(src_attrs, fn(src_attr) {
            let img = V(blame, "img", [src_attr], [])
            V(blame, "CarouselItem", [], [img])
          })
          Ok(V(blame, "Carousel", [], carousel_items))
        }
        _ -> {
          // check if there are any src attributes - error if there are
          case list.any(attrs, fn(attr) { attr.key == "src" }) {
            True ->
              Error(DesugaringError(
                blame,
                "Carousel cannot have src attribute and children at the same time."
              ))
            False -> Ok(vxml)
          }
        }
      }
    }
    _ -> Ok(vxml)
  }
}

fn nodemap_factory() -> n2t.OneToOneNodeMap {
  nodemap
}

fn transform_factory() -> DesugarerTransform {
  nodemap_factory()
  |> n2t.one_to_one_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(_param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(Nil)
}

const name = "expand_ti3_carousel"
const constructor = expand_ti3_carousel

type Param = Nil
type InnerParam = Nil

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// Expands compressed Carousel syntax to full form.
///
/// Transforms:
/// ```
/// |> Carousel
///     src=blabla
///     src=bloblo
/// ```
///
/// To:
/// ```
/// |> Carousel
///     |> CarouselItem
///         |> img
///             src=blabla
///     |> CarouselItem
///         |> img
///             src=bloblo
/// ```
///
/// Validates that compressed Carousel has:
/// - No children
/// - Only src attributes
/// - At least one src attribute
pub fn expand_ti3_carousel() -> Desugarer {
  Desugarer(
    name,
    None,
    None,
    "
/// Expands compressed Carousel syntax to full form.
///
/// Transforms:
/// ```
/// |> Carousel
///     src=blabla
///     src=bloblo
/// ```
///
/// To:
/// ```
/// |> Carousel
///     |> CarouselItem
///         |> img
///             src=blabla
///     |> CarouselItem
///         |> img
///             src=bloblo
/// ```
///
/// Validates that compressed Carousel has:
/// - No children
/// - Only src attributes
/// - At least one src attribute
    ",
    case param_to_inner_param(Nil) {
      Error(e) -> fn(_) { Error(e) }
      Ok(_) -> transform_factory()
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestDataNoParam) {
  [
    infra.AssertiveTestDataNoParam(
      source:   "
                <> Carousel
                  src=\"image1.jpg\"
                  src=\"image2.jpg\"
                  src=\"image3.jpg\"
                ",
      expected: "
                <> Carousel
                  <> CarouselItem
                    <> img
                      src=\"image1.jpg\"
                  <> CarouselItem
                    <> img
                      src=\"image2.jpg\"
                  <> CarouselItem
                    <> img
                      src=\"image3.jpg\"
                ",
    ),
    infra.AssertiveTestDataNoParam(
      source:   "
                <> root
                  <> Carousel
                    src=\"single.jpg\"
                  <> div
                    <>
                      \"Other content\"
                ",
      expected: "
                <> root
                  <> Carousel
                    <> CarouselItem
                      <> img
                        src=\"single.jpg\"
                  <> div
                    <>
                      \"Other content\"
                ",
    ),
    infra.AssertiveTestDataNoParam(
      source:   "
                <> root
                  <> div
                    <>
                      \"No carousel here\"
                ",
      expected: "
                <> root
                  <> div
                    <>
                      \"No carousel here\"
                ",
    ),
  ]
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_no_param(name, assertive_tests_data(), constructor)
}
