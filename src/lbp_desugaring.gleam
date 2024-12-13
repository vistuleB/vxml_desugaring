import argv
import gleam/io
import gleam/result
import gleam/string
import infrastructure.{
  type DesugaringError, type Pipe, DesugaringError, get_root,
}
import leptos_emitter
import pipeline.{pipeline_constructor}
import pipeline_debug.{pipeline_introspection_lines2string}
import vxml_parser.{type VXML}
import writerly_parser.{
  assemble_blamed_lines, parse_blamed_lines, writerlys_to_vxmls,
}

const ins = string.inspect

pub const path = "test/sample.emu"

pub fn desugar_internal(
  vxml: VXML,
  pipeline: List(Pipe),
) -> Result(VXML, DesugaringError) {
  case pipeline {
    [] -> Ok(vxml)
    [#(_, desugarer), ..rest] -> {
      result.try(desugarer(vxml), desugar_internal(_, rest))
    }
  }
}

pub fn desugar(
  vxmls: List(VXML),
  pipeline: List(Pipe),
) -> Result(VXML, DesugaringError) {
  case get_root(vxmls) {
    Ok(root) -> desugar_internal(root, pipeline)
    Error(e) -> Error(e)
  }
}

fn assemble_and_desugar(path: String, on_success: fn(VXML) -> Nil) {
  io.println(path)
  case assemble_blamed_lines(path) {
    Error(e) -> {
      io.println("get error from assemble_blamed_lines: " <> ins(e))
    }
    Ok(assembled) -> {
      let assert Ok(writerlys) = parse_blamed_lines(assembled, False)
      let vxmls = writerlys_to_vxmls(writerlys)
      case desugar(vxmls, pipeline_constructor()) {
        Ok(desugared) -> on_success(desugared)
        Error(err) -> io.println("there was a desugaring error: " <> ins(err))
      }
    }
  }
}

pub fn main() {
  let args = argv.load().arguments
  case args {
    [path] -> {
      assemble_and_desugar(path, fn(desugared) {
        vxml_parser.debug_print_vxml("", desugared)
      })
    }
    [path, "--debug"] -> {
      let assert Ok(assembled) = assemble_blamed_lines(path)
      pipeline_introspection_lines2string(assembled, pipeline_constructor())
      |> io.print()
    }
    [path, "--emit-book", emitter, "--output", output_folder] -> {
      assemble_and_desugar(path, fn(desugared) {
        leptos_emitter.write_splitted(desugared, output_folder, emitter)
      })
    }
    [path, "--emit", emitter, "--output", output_file] -> {
      assemble_and_desugar(path, fn(desugared) {
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
