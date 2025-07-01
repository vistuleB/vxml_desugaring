import gleam/list
import argv
import gleam/io
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Pipe} as infra
import vxml_renderer as vr
import writerly as wp
import desugarer_names as dn
import desugarer_tests as dt

fn test_pipeline() -> List(Pipe) {
  [
    dn.extract_starting_and_ending_spaces(["i", "b", "strong"]),
    dn.insert_bookend_text_if_no_attributes([
      #("i", "_", "_"),
      #("b", "*", "*"),
      #("strong", "*", "*") ,
    ]),
    dn.unwrap_tags_if_no_attributes(["i", "b", "strong"]),
    dn.cut_paste_attribute_from_first_child_to_self(#("Book", "title"))
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
      input_dir: "test/content/__parent.emu",
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

fn run_desugarer_tests(desugarer_name: String) {
  use test_group <- infra.on_error_on_ok(
    list.find(dt.all_test_groups, fn(test_group){
      test_group().name == desugarer_name
    }),
    fn(_) {
      io.println("No desugarer found with name " <> desugarer_name)
    }
  )
  infra.run_assertive_tests(test_group())
  Nil
}

pub fn main() {
  case argv.load().arguments {
    ["--test-desugarer", name] -> run_desugarer_tests(name)
    _ -> test_renderer()
  }
}
