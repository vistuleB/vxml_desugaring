import gleam/list
import gleam/result
import simplifile
import gleam/float
import gleam/int
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugaringError, DesugaringError, type DesugarerTransform} as infra
import vxml.{type VXML, BlamedAttribute, V}
import blamedlines.{type Blame}
import gleam/regexp
import nodemaps_2_desugarer_transforms as n2t
import ansel/image.{read, get_width}

fn get_svg_width(blame: Blame, path: String) -> Result(Float, DesugaringError) {
  let assert Ok(file) = simplifile.read(path)
  let assert True = string.starts_with(file, "<svg ") || string.starts_with(file, "<?xml ")
  let assert Ok(width_pattern) = regexp.from_string("width=\"([0-9.]+)(.*)\"")
  
  use match, _ <- infra.on_empty_on_nonempty(
    regexp.scan(width_pattern, file),
    Error(DesugaringError(blame, "Could not find width attribute in SVG file\n file: " <> path))
  )

  case match.submatches {
    [Some(width_str), ..] -> {
      case float.parse(width_str), int.parse(width_str)  {
        Ok(width), _ -> Ok(width)
        _, Ok(width) -> Ok(int.to_float(width))
        _, _ -> Error(DesugaringError(blame, "Invalid width value in SVG file\n file: " <> path))
      }
    }
    _ -> Error(DesugaringError(blame, "Could not extract width value from SVG file\n file: " <> path))
  }
}

// fn get_bitmap_image_width_with_imagemagick(blame: Blame, path: String) -> Result(Float, DesugaringError) {
//   // Use ImageMagick's identify command to get image dimensions
//   // Format: identify -format "%w" image.png
//   case shellout.command(
//     run: "identify",
//     in: ".",
//     with: ["-format", "%w", path],
//     opt: []
//   ) {
//     Ok(width_str) -> {
//       let width_str = string.trim(width_str)
//       case float.parse(width_str), int.parse(width_str) {
//         Ok(width), _ -> Ok(width)
//         _, Ok(width) -> Ok(int.to_float(width))
//         _, _ -> Error(DesugaringError(blame, "Invalid width value returned by identify command: " <> width_str <> "\n file: " <> path))
//       }
//     }
//     Error(#(exit_code, error_msg)) -> {
//       Error(DesugaringError(blame, "Failed to get image width using identify command (exit code: " <> int.to_string(exit_code) <> "): " <> error_msg <> "\n file: " <> path <> "\nMake sure ImageMagick is installed"))
//     }
//   }
// }

fn get_bitmap_image_width_with_ansel(blame: Blame, path: String) -> Result(Float, DesugaringError) {
  case read(path) {
    Ok(img) -> Ok(get_width(img) |> int.to_float)
    Error(error) -> Error(DesugaringError(blame, ins(error)))
  }
}

fn get_image_width(blame: Blame, path: String) -> Result(Float, DesugaringError) {
  let assert [extension, ..] = string.split(path, ".") |> list.reverse

  case extension {
    "svg"  -> get_svg_width(blame, path)
    _ -> get_bitmap_image_width_with_ansel(blame, path)
  }
}

fn nodemap(
  node: VXML,
) -> Result(VXML, DesugaringError) {
  case node {
    V(blame, tag, attributes, _) 
      if tag == "ImageLeft" || tag == "ImageRight" || tag == "Image" -> {
        // if the image has a width attribute, we don't need to do anything
        use <- infra.on_some_on_none(
          over: infra.v_attribute_with_key(node, "width"),
          with_on_some: fn(_) {Ok(node)},
        )

        // if the image doesn't have a src attribute, we need to error
        use attr <- infra.on_none_on_some(
          over: infra.v_attribute_with_key(node, "src"),
          with_on_none: Error(DesugaringError(blame, "Image tag must have a src attribute")),
        )
       
        use width <- result.try(get_image_width(attr.blame, "../../../MrChaker/little-bo-peep-solid/public" <> attr.value))
        Ok(V(..node, attributes: [BlamedAttribute(blame, "width", ins(width) <> "px"), ..attributes]))
      }
    _ -> Ok(node)
  }
}

fn nodemap_factory() -> n2t.OneToOneNodeMap {
  nodemap
}

fn transform_factory() -> DesugarerTransform {
  n2t.one_to_one_nodemap_2_desugarer_transform(nodemap_factory())
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

const name = "compute_missing_images_width"
const constructor = compute_missing_images_width

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// compute missing images widths
pub fn compute_missing_images_width() -> Desugarer {
  Desugarer(
    name,
    option.None,
    option.None,
    "
/// compute missing images widths
    ",
    case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(_) -> transform_factory()
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestDataNoParam) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data_no_param(name, assertive_tests_data(), constructor)
}