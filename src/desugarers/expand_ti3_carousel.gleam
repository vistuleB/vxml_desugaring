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
          // get img-width and img-height attributes if they exist
          let img_width_attr = list.filter(attrs, fn(attr) { attr.key == "img-width" })
          let img_height_attr = list.filter(attrs, fn(attr) { attr.key == "img-height" })

          // validate only one img-width attribute
          case list.length(img_width_attr) > 1 {
            True -> Error(DesugaringError(
              blame,
              "Carousel should have only one img-width attribute."
            ))
            False -> case list.length(img_height_attr) > 1 {
              True -> Error(DesugaringError(
                blame,
                "Carousel should have only one img-height attribute."
              ))
              False -> {
                // create CarouselItem children with img tags
                let carousel_items = list.map(src_attrs, fn(src_attr) {
                  let base_attrs = [src_attr]

                  // build style attribute from img-width and img-height
                  let style_value = case img_width_attr, img_height_attr {
                    [], [] -> ""
                    [width_attr], [] -> "width: " <> width_attr.value <> ";"
                    [], [height_attr] -> "height: " <> height_attr.value <> ";"
                    [width_attr], [height_attr] -> "width: " <> width_attr.value <> "; height: " <> height_attr.value <> ";"
                    _, _ -> "" // should never happen due to validation above
                  }

                  let final_attrs = case style_value {
                    "" -> base_attrs
                    _ -> {
                      let style_blame = case img_width_attr, img_height_attr {
                        [width_attr], _ -> width_attr.blame
                        [], [height_attr] -> height_attr.blame
                        _, _ -> blame
                      }
                      list.append(base_attrs, [vxml.BlamedAttribute(style_blame, "style", style_value)])

                    }
                  }

                  let img = V(blame, "img", final_attrs, [])
                  V(blame, "CarouselItem", [], [img])
                })
                Ok(V(blame, "Carousel", [], carousel_items))
              }
            }
          }
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
/// - Only src, img-width, and img-height attributes
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
/// - Only src, img-width, and img-height attributes
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
                <> Carousel
                  src=\"image1.jpg\"
                  src=\"image2.jpg\"
                  img-width=200px
                  img-height=150px
                ",
      expected: "
                <> Carousel
                  <> CarouselItem
                    <> img
                      src=\"image1.jpg\"
                      style=width: 200px; height: 150px;
                  <> CarouselItem
                    <> img
                      src=\"image2.jpg\"
                      style=width: 200px; height: 150px;
                ",
    ),
    infra.AssertiveTestDataNoParam(
      source:   "
                <> Carousel
                  src=\"only.jpg\"
                  img-width=100px
                ",
      expected: "
                <> Carousel
                  <> CarouselItem
                    <> img
                      src=\"only.jpg\"
                      style=width: 100px;
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
