import gleam/list
import argv
import gleam/io
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer} as infra
import vxml_renderer as vr
import writerly as wp
import desugarer_library as dl

fn test_pipeline() -> List(Desugarer) {
  [
    dl.extract_starting_and_ending_spaces(["i", "b", "strong"]),
    dl.insert_bookend_text_if_no_attributes([
      #("i", "_", "_"),
      #("b", "*", "*"),
      #("strong", "*", "*") ,
    ]),
    dl.unwrap_tags_if_no_attributes(["i", "b", "strong"]),
    dl.cut_paste_attribute_from_first_child_to_self(#("Book", "title"))
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

fn run_desugarer_tests(names: List(String)) {
  let run_all = list.is_empty(names)

  let #(found, tested) =
    list.fold(
      dl.assertive_tests,
      #([], []),
      fn(acc, constructor) {
        let name = constructor().name
        case run_all || list.contains(names, name) {
          False -> acc
          True -> {
            let #(num_passed, num_failed) = infra.run_assertive_tests(constructor())
            case num_passed + num_failed > 0 {
              True -> #([name, ..acc.0], [name, ..acc.1])
              False -> {
                // io.println("trying to signal that desugarer '" <> name <> "' has empty test group")
                #([name, ..acc.0], acc.1)
              }
            }
          }
        }
      }
    )

  let report_on = case list.is_empty(names) {
    True -> found
    False -> names
  }

  let desugarers_with_no_test_group = list.filter(report_on, fn(name) { !list.contains(found, name)})
  let desugarers_with_no_empty_test_group = list.filter(report_on, fn(name) { !list.contains(tested, name)})

  case list.is_empty(desugarers_with_no_empty_test_group) {
    True -> Nil
    False -> {
      io.println("")
      io.println("the following desugarers have empty test groups:")
      list.each(
        desugarers_with_no_empty_test_group,
        fn(name) { io.println(" - " <> name)}
      )
    }
  }

  case list.is_empty(desugarers_with_no_test_group) {
    True -> Nil
    False -> {
      io.println("")
      io.println("could not find test groups for the following desugarers:")
      list.each(
        desugarers_with_no_test_group,
        fn(name) { io.println(" - " <> name)}
      )
    }
  }
}

pub fn main() {
  case argv.load().arguments {
    ["--test-desugarers", ..names] -> run_desugarer_tests(names)
    _ -> test_renderer()
  }
}
