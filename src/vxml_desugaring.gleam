import vxml
import shellout
import gleam/list
import argv
import gleam/io
import gleam/string.{inspect as ins}
import infrastructure.{type Pipe} as infra
import vxml_renderer as vr
import desugarer_library as dl
import selector_library as sl

fn test_pipeline() -> List(Pipe) {
  let echo_mode = infra.Off
  let selector = sl.tag("marker")
  [
    dl.extract_starting_and_ending_spaces(["i", "b", "strong"]),
    dl.insert_text_start_end(#("i", #("_", "_"))),
    dl.insert_text_start_end(#("b", #("*", "*"))),
    dl.insert_text_start_end(#("strong", #("*", "*"))),
    dl.unwrap__batch(["i", "b", "strong"]),
    dl.cut_paste_attribute_from_first_child_to_self(#("Book", "title"))
  ]
  |> infra.wrap_desugarers(echo_mode, selector)
}

fn test_renderer() {
  use amendments <- infra.on_error_on_ok(
    vr.process_command_line_arguments(argv.load().arguments, []),
    fn(e) {
      io.println("")
      io.println("cli error: " <> ins(e))
      vr.cli_usage()
    },
  )

  use <- infra.on_true_on_false(
    amendments.help,
    io.println("test_renderer exiting on '--help' option"),
  )

  let renderer =
    vr.Renderer(
      assembler: vr.default_blamed_lines_assembler(amendments.spotlight_paths),
      source_parser: vr.default_writerly_source_parser(amendments.spotlight_key_values),
      pipeline: test_pipeline(),
      splitter: vr.stub_splitter(".tsx"),
      emitter: vr.stub_jsx_emitter,
      prettifier: vr.default_prettier_prettifier,
    )
    |> vr.amend_renderer_by_command_line_amendments(amendments)

  let parameters =
    vr.RendererParameters(
      input_dir: "test/content",
      output_dir: "test/output",
      prettifier_on_by_default: False,
    )
    |> vr.amend_renderer_paramaters_by_command_line_amendments(amendments)

  let debug_options =
    vr.default_renderer_debug_options()
    |> vr.amend_renderer_debug_options_by_command_line_amendments(amendments)

  let _ = vr.run_renderer(renderer, parameters, debug_options)

  Nil
}

fn generate_desugarer_library() {
  let _ = shellout.command(
    run: "generate_library.sh",
    in: ".",
    with: [],
    opt: [],
  )
  Nil
}

fn run_desugarer_tests(names: List(String)) {
  let #(all, dont_have_tests) =
    list.fold(
      dl.assertive_tests,
      #([], []),
      fn(acc, constructor) {
        let w = constructor()
        case list.length(w.tests()) > 0 {
          True -> #([w.name, ..acc.0], acc.1)
          False -> #([w.name, ..acc.0], [w.name, ..acc.1])
        }
      }
    )

  let names = case list.is_empty(names) {
    True -> all
    False -> names
  }

  let dont_have_tests = list.filter(dont_have_tests, list.contains(names, _))

  case list.is_empty(dont_have_tests) {
    True -> Nil
    False -> {
      io.println("")
      io.println("the following desugarers have empty test data:")
      list.each(
        dont_have_tests,
        fn(name) { io.println(" - " <> name)}
      )
    }
  }

  io.println("")
  let #(num_performed, num_failed) =
    list.fold(
      dl.assertive_tests,
      #(0, 0),
      fn(acc, constructor) {
        let w = constructor()
        case list.contains(names, w.name) && list.length(w.tests()) > 0 {
          False -> acc
          True -> {
            let #(_, num_failed) = infra.run_assertive_tests(w)
            case num_failed > 0 {
              True -> #(acc.0 + 1, acc.1 + 1)
              False -> #(acc.0 + 1, acc.1)
            }
          }
        }
      }
    )

  io.println("")
  io.println(
    ins(num_performed)
    <> case num_performed == 1 {
      True -> " desugarer tested, "
      False -> " desugarers tested, "
    }
    <> ins(num_failed)
    <> case num_failed == 1 {
      True -> " failed"
      False -> " failures"
    }
  )

  let desugarers_with_no_test_group = list.filter(names, fn(name) { !list.contains(all, name)})
  case list.is_empty(desugarers_with_no_test_group) {
    True -> Nil
    False -> {
      io.println("")
      io.println("could not find any test data for the following desugarers:")
      list.each(
        desugarers_with_no_test_group,
        fn(name) { io.println(" - " <> name)}
      )
    }
  }

  Nil
}

pub fn test_thing() {
  let assert Ok([vxml]) = vxml.parse_file("test/sample.vxml")
  echo vxml
  Nil
}

pub fn main() {
  case argv.load().arguments {
    ["--test-thing"] -> {
      test_thing()
    }
    ["--test-desugarers", ..names] -> {
      run_desugarer_tests(names)
    }
    ["--generate-lib"] | ["--generate"] | ["--generate-library"] -> {
      generate_desugarer_library()
    }
    _ -> {
      io.println("")
      io.println("No local command line options given. Will run the test renderer.")
      test_renderer()
    }
  }
}
