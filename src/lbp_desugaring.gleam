import desugarers/encode_spaces_in_first_and_last_child.{encode_spaces_in_first_and_last_child}
import desugarers/fold_tags_into_text.{fold_tags_into_text}
import desugarers/insert_bookend_tags.{insert_bookend_tags}
import desugarers/unwrap_tags.{unwrap_tags}
import gleam/io
import infrastructure.{type Pipe}
// import vxml_renderer as vr

// got lazy and didn't finish writing test facilities for a pipeline
// (would need to )
fn test_pipeline() -> List(Pipe) {
  [
    // this first desugarer is actually not what we want,
    // we should probably have something like...
    // "extricate_starting_and_ending_spaces_as_sibilings"
    // ...that turns...
    //
    // <> i
    //   <>
    //     "  two spaces at start, "
    //   <>
    //     "two spaces at end  "
    //
    // ...into...
    //
    // <>
    //   "  "
    // <> i
    //   <>
    //      "two spaces at start, "
    //   <>
    //      "two spaces at end"
    // <>
    //   "  "
    //
    // but for now I wrote this:
    encode_spaces_in_first_and_last_child(["i", "b", "strong"]),


    // from here on the <i> -> _..._ pipeline is correct:
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
  ]
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
  io.println("\nthis is an empty shell now; thank u for using\n")
}