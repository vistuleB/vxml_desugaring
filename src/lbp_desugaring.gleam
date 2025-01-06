import argv
import gleam/io
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugaringError, announce_error, get_root,
  on_error_on_ok,
}
import leptos_emitter
import pipeline.{pipeline_constructor}
import pipeline_debug.{desugarer_description_star_block, star_block}
import vxml_parser.{type VXML}
import writerly_parser

pub const path = "test/sample.emu"

const ins = string.inspect

pub fn desugar(
  vxml: VXML,
  pipeline: List(Pipe),
  step: Int,
  debug: Bool,
) -> Result(VXML, DesugaringError) {
  case pipeline {
    [] -> Ok(vxml)
    [#(desugarer_desc, desugarer), ..rest] -> {
      case debug {
        False -> Nil
        True -> io.print(desugarer_description_star_block(desugarer_desc, step))
      }

      case desugarer(vxml) {
        Ok(vxml) -> {
          case debug {
            False -> Nil
            True -> vxml_parser.debug_print_vxml("(" <> ins(step) <> ")", vxml)
          }
          desugar(vxml, rest, step + 1, debug)
        }
        Error(error) -> Error(error)
      }
    }
  }
}

fn assemble_and_desugar(path: String, debug: Bool, on_success: fn(VXML) -> Nil) {
  io.print("\nassemble_and_desugar: " <> path <> "\n\n")

  use lines <- on_error_on_ok(
    writerly_parser.assemble_blamed_lines(path),
    announce_error("got an error from writerly_parser.assemble_blamed_lines: "),
  )

  use writerlys <- on_error_on_ok(
    writerly_parser.parse_blamed_lines(lines, False),
    announce_error("got an error from writerly_parser.parse_blamed_lines: "),
  )

  case debug {
    False -> Nil
    True ->
      {
        star_block(False, ["SOURCE"], True)
        <> writerly_parser.debug_writerlys_to_string("", writerlys)
      }
      |> io.print
  }

  let vxmls = writerly_parser.writerlys_to_vxmls(writerlys)

  use vxml <- on_error_on_ok(
    get_root(vxmls),
    announce_error("got an error from get_root before starting pipeline: "),
  )

  case debug {
    False -> Nil
    True ->
      {
        star_block(True, ["PARSE WLY -> VXML"], True)
        <> vxml_parser.debug_vxml_to_string("", vxml)
      }
      |> io.print
  }

  let pipeline = pipeline_constructor()

  use desugared <- on_error_on_ok(
    desugar(vxml, pipeline, 1, debug),
    announce_error("there was a desugaring error"),
  )

  on_success(desugared)
}

pub fn emit_book(
  path path: String,
  emitter emitter: String,
  output_folder output_folder: String,
) {
  assemble_and_desugar(path, False, fn(desugared) {
    leptos_emitter.write_splitted(desugared, output_folder, emitter)
  })
}

pub fn main() {
  let args = argv.load().arguments
  case args {
    [path] -> {
      assemble_and_desugar(path, False, fn(desugared) {
        vxml_parser.debug_print_vxml("", desugared)
      })
    }
    [path, "--debug"] -> {
      assemble_and_desugar(path, True, fn(_) { Nil })
    }
    [path, "--emit-book", emitter, "--output", output_folder] -> {
      emit_book(path, emitter, output_folder)
    }
    [path, "--emit", emitter, "--output", output_file] -> {
      assemble_and_desugar(path, False, fn(desugared) {
        leptos_emitter.write_file(desugared, output_file, emitter)
      })
    }
    _ ->
      io.println(
        "usage: executable_file_name <input_file>
        options:
            <input_file> --debug : debug pipeline steps
            <input_file> --emit <emitter> --output <output_file>
            <input_file> --emit-book <emitter> --output <output_file>
            ",
      )
  }
}
