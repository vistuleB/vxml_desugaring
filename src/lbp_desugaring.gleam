import gleam/io
import desugarers/extract_starting_and_ending_spaces.{extract_starting_and_ending_spaces}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_bookend_tags.{insert_bookend_tags}
import desugarers/insert_bookend_text_if_no_attributes.{insert_bookend_text_if_no_attributes}
import desugarers/unwrap_tags.{unwrap_tags}
import desugarers/unwrap_tags_if_no_attributes.{unwrap_tags_if_no_attributes}
import infrastructure.{type Pipe}

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

// fn test_renderer() {
//   dr.run_default_renderer(
//     test_pipeline(),
//     argv.load().arguments,
//   )
// }

pub fn main() {
  // test_renderer()
  io.println("\nthis is an empty shell now; thank u for using\n")
}