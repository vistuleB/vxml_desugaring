import argv
import desugarers/extract_starting_and_ending_spaces.{extract_starting_and_ending_spaces}
import desugarers/insert_bookend_text_if_no_attributes.{insert_bookend_text_if_no_attributes}
import desugarers/unwrap_tags_if_no_attributes.{unwrap_tags_if_no_attributes}
import gleam/io
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Pipe} as infra
import vxml_renderer as vr
import writerly as wp

fn test_pipeline() -> List(Pipe) {
  [
    extract_starting_and_ending_spaces(["i", "b", "strong"]),
    insert_bookend_text_if_no_attributes([
      #("i", "_", "_"),
      #("b", "*", "*"),
      #("strong", "*", "*"),
    ]),
    unwrap_tags_if_no_attributes(["i", "b", "strong"]),
  ]
}

fn cli_usage_supplementary() {
  io.println("      --prettier")
  io.println("         -> run npm prettier on emitted content")
}

fn test_renderer() {
  use amendments <- infra.on_error_on_ok(
    vr.process_command_line_arguments(argv.load().arguments, ["--prettier"]),
    fn(error) {
      io.println("\ncommand line error: " <> ins(error) <> "\n")
      vr.cli_usage()
      cli_usage_supplementary()
    },
  )

  let renderer =
    vr.Renderer(
      assembler: wp.assemble_blamed_lines_advanced_mode(
        _,
        amendments.spotlight_args_files,
      ),
      source_parser: vr.default_writerly_source_parser(
        _,
        amendments.spotlight_args,
      ),
      pipeline: test_pipeline(),
      splitter: vr.empty_splitter(_, ".tsx"),
      // emitter: vr.stub_html_emitter,
      emitter: vr.stub_jsx_emitter,
      prettifier: vr.guarded_prettier_prettifier(amendments.user_args),
    )

  let parameters =
    vr.RendererParameters(
      input_dir: "test/content",
      output_dir: Some("test/output"),
    )
    |> vr.amend_renderer_paramaters_by_command_line_amendment(amendments)

  let debug_options =
    vr.empty_renderer_debug_options("../renderer_artifacts")
    |> vr.amend_renderer_debug_options_by_command_line_amendment(
      amendments,
      renderer.pipeline,
    )

  case vr.run_renderer(renderer, parameters, debug_options) {
    Ok(Nil) -> Nil
    Error(error) -> io.println("\nrenderer error: " <> ins(error) <> "\n")
  }
}

pub fn main() {
  test_renderer()
}
