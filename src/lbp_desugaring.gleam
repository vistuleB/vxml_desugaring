import argv
import desugarers/extract_starting_and_ending_spaces.{extract_starting_and_ending_spaces}
import desugarers/encode_spaces_in_first_and_last_child.{encode_spaces_in_first_and_last_child}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_bookend_tags.{insert_bookend_tags}
import desugarers/insert_bookend_text_if_no_attributes.{insert_bookend_text_if_no_attributes}
import desugarers/unwrap_tags.{unwrap_tags}
import desugarers/unwrap_tags_if_no_attributes.{unwrap_tags_if_no_attributes}
import gleam/io
import infrastructure.{type Pipe}
import default_renderer as dr
import vxml_renderer as vr

// got lazy and didn't finish writing test facilities for a pipeline
// (would need to )
fn test_pipeline() -> List(Pipe) {
  [
    // OLD SUGGESTION:
    insert_bookend_tags([
      #("i", "OpeningUnderscore", "ClosingUnderscore"),
      #("b", "OpeningAsterisk", "ClosingAsterisk"),
      #("strong", "OpeningAsterisk", "ClosingAsterisk"),
    ]),
    fold_tags_into_text([
      #("OpeningUnderscore", "_"),
      #("ClosingUnderscore", "_"),
      #("OpeningAsterisk", "*"),
      #("ClosingAsterisk", "*"),
    ]),
    unwrap_tags(["i", "b", "strong"]),

    // NEW SUGGESTION:
    extract_starting_and_ending_spaces(["i", "b", "strong"]),
    insert_bookend_text_if_no_attributes([
      #("i", "_", "_"),
      #("b", "*", "*"),
      #("strong", "*", "*"),
    ]),
    unwrap_tags_if_no_attributes.unwrap_tags_if_no_attributes(["i", "b", "strong"]),

  ]
}

fn test_renderer() {
  dr.run_default_renderer(
    test_pipeline(),
    argv.load().arguments,
  )
}

// need to write 'vanilla_renderer()' in vxml_renderer:

// fn test_renderer() -> vr.Renderer(
//   Nil,
//   Nil,
//   Nil,
//   Nil,
//   Nil,
//   Nil,
//   Nil,
//   Nil,
// ) {
//   vr.vanilla_renderer()
// }

pub fn main() {
  test_renderer()
  // io.println("\nthis is an empty shell now; thank u for using\n")
}