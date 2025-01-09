import gleam/int
import argv
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugaringError, get_root, nillify_error,
  on_error_on_ok,
}
import leptos_emitter
import pipeline
import pipeline_debug.{desugarer_description_star_block, star_block}
import vxml_parser.{type VXML}
import writerly_parser

pub const path = "test/sample.emu"

const ins = string.inspect

pub fn desugar(
  vxml: VXML,
  pipeline: List(Pipe),
  step: Int,
  debug_start: Int,
  debug_end: Int
) -> Result(VXML, DesugaringError) {
  case pipeline {
    [] -> Ok(vxml)
    [#(desugarer_desc, desugarer), ..rest] -> {
      case step == debug_start - 1 && step <= debug_end {
        False -> Nil
        True -> io.println(".\n.\n.\n.\n.")
      }

      case debug_start <= step && step <= debug_end {
        False -> Nil
        True -> io.print(desugarer_description_star_block(desugarer_desc, step))
      }

      case step == debug_end + 1 && debug_end >= 1 {
        False -> Nil
        True -> io.println(".\n.\n.\n.\n.")
      }

      case desugarer(vxml) {
        Ok(vxml) -> {
          case debug_start <= step && step <= debug_end {
            False -> Nil
            True -> vxml_parser.debug_print_vxml("(" <> ins(step) <> ")", vxml)
          }
          desugar(vxml, rest, step + 1, debug_start, debug_end)
        }
        Error(error) -> Error(error)
      }
    }
  }
}

pub fn assemble_and_desugar(
  path: String,
  pipeline: List(Pipe),
  debug_start: Int,
  debug_end: Int
) -> Result(VXML, Nil) {
  let #(debug_start, debug_end) = case debug_start == 0 && debug_end == 0 {
    False -> #(debug_start, debug_end)
    True -> #(0, list.length(pipeline))
  }

  use lines <- on_error_on_ok(
    writerly_parser.assemble_blamed_lines(path),
    nillify_error("got an error from writerly_parser.assemble_blamed_lines: "),
  )

  use writerlys <- on_error_on_ok(
    writerly_parser.parse_blamed_lines(lines, False),
    nillify_error("got an error from writerly_parser.parse_blamed_lines: "),
  )

  case debug_end >= 1 {
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
    nillify_error("got an error from get_root before starting pipeline: "),
  )

  case debug_end >= 1 {
    False -> Nil
    True ->
      {
        star_block(True, ["PARSE WLY -> VXML"], True)
        <> vxml_parser.debug_vxml_to_string("", vxml)
      }
      |> io.print
  }

  use desugared <- on_error_on_ok(
    desugar(vxml, pipeline, 1, debug_start, debug_end),
    nillify_error("there was a desugaring error"),
  )

  Ok(desugared)
}

fn assemble_and_desugar_wrapper(
  path: String,
  debug_start: Int,
  debug_end: Int,
  on_success: fn(VXML) -> Nil,
) -> Nil {
  assemble_and_desugar(path, pipeline.pipeline_constructor(), debug_start, debug_end)
  |> result.map(on_success)
  |> result.unwrap(Nil)
}

pub fn emit_book(
  path path: String,
  emitter emitter: String,
  output_folder output_folder: String,
) {
  assemble_and_desugar_wrapper(path, -1, -1, fn(desugared) {
    leptos_emitter.write_splitted(desugared, output_folder, emitter)
  })
}

fn usage_message() {
  io.println(
    "usage: executable_file_name <input_file>
    options:
        <input_file> --debug : debug pipeline steps
        <input_file> --emit <emitter> --output <output_file>
        <input_file> --emit-book <emitter> --output <output_file>
        <input_file> --debug-<start:int>-<end:int> : debug pipeline steps with start & stop indices
        <input_file> --debug-<start:int> : shorthand for --debug-<start>-<start>
        ",
  )
}

pub fn main() {
  let args = argv.load().arguments
  case args {
    [path] -> {
      assemble_and_desugar_wrapper(path, -1, -1, fn(desugared) {
        vxml_parser.debug_print_vxml("", desugared)
      })
    }
    [path, "--debug"] -> {
      assemble_and_desugar_wrapper(path, 0, 0, fn(_) { Nil })
    }
    [path, "--emit-book", emitter, "--output", output_folder] -> {
      emit_book(path, emitter, output_folder)
    }
    [path, "--emit", emitter, "--output", output_file] -> {
      assemble_and_desugar_wrapper(path, -1, -1, fn(desugared) {
        leptos_emitter.write_file(desugared, output_file, emitter)
      })
    }
    [path, maybe_debug_range] -> {
      io.println("hello")
      case string.starts_with(maybe_debug_range, "--debug") {
        False -> usage_message()
        True -> {
          io.println("hello2")
          let suffix = string.drop_start(maybe_debug_range, 7)
          let pieces = string.split(suffix, "-")
          case list.length(pieces) {
            3 -> {
              let assert [_, b, c] = pieces
              case int.parse(b), int.parse(c) {
                Ok(debug_start), Ok(debug_end) ->
                  assemble_and_desugar_wrapper(path, debug_start, debug_end, fn(_) { Nil })
                _, _ ->  usage_message()
              }
            }
            2 -> {
              let assert [_, b] = pieces
              case int.parse(b) {
                Ok(debug_start) ->
                  assemble_and_desugar_wrapper(path, debug_start, debug_start, fn(_) { Nil })
                _ ->  usage_message()
              }
            }
            _ -> {
              io.println("goodbye " <> ins(pieces) <> ", " <> suffix <> "[]")
              usage_message()
            }
          }
        }
      }
    }
    _ -> usage_message()
  }
}
