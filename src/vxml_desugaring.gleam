import gleam/list
import argv
import gleam/io
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer} as infra
import vxml_renderer as vr
import writerly as wp
import desugarer_library as dl
import simplifile

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

fn test_renderer() {
  use amendments <- infra.on_error_on_ok(
    vr.process_command_line_arguments(argv.load().arguments, []),
    fn(e) {
      io.println("\ncommand line error: " <> ins(e) <> "\n")
      vr.cli_usage()
    },
  )

  use <- infra.on_true_on_false(
    amendments.info,
    Nil,
  )

  let renderer =
    vr.Renderer(
      assembler: wp.assemble_blamed_lines_advanced_mode(_, amendments.spotlight_args_files),
      source_parser: vr.default_writerly_source_parser(_, amendments.spotlight_args),
      pipeline: test_pipeline(),
      splitter: vr.empty_splitter(_, ".tsx"),
      emitter: vr.stub_jsx_emitter,
      prettifier: vr.default_prettier_prettifier,
    )

  let parameters =
    vr.RendererParameters(
      input_dir: "test/content/__parent.emu",
      output_dir: "test/output",
      prettifier_on_by_default: False,
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

//*********************
//* library generator *
//*********************

pub fn desugarer_library_generator() -> Nil {
  let assert Ok(desugarers) = simplifile.read_directory("src/desugarers")
  let desugarers = 
  desugarers
  |> list.filter(fn(name) { ! string.starts_with(name, "__")})
  |> list.map(fn(name) { string.drop_end(name, 6) })
  |> list.sort(string.compare)

  let imports = [
    [
      "import infrastructure as infra"
    ],
    list.map(desugarers, fn(name) {
      "import desugarers/" <> name
    })
  ] |> list.flatten

  let consts = list.map(desugarers, fn(name) {
    "pub const " <> name <> " = " <> name <> "." <> name 
  })

  let assertive_tests = [
    ["pub const assertive_tests : List(fn() -> infra.AssertiveTests) = ["],
    list.map(desugarers, fn(name) {
        name <> ".assertive_tests,"
    }),
    ["]"]
  ] |> list.flatten

  let source = [
    imports,
    consts,
    assertive_tests,
  ] |> list.flatten |> string.join("\n")

  let _ = simplifile.write("src/desugarer_library.gleam", source)
  Nil
}


pub fn main() {
  case argv.load().arguments {
    ["--test-desugarers", ..names] -> run_desugarer_tests(names)
    ["--generate-library"] -> desugarer_library_generator()
    _ -> test_renderer()
  }
}
