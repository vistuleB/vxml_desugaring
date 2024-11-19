import pipeline_constructor.{pipeline_constructor}
import gleam/io
import desugarers_docs.{ type Pipeline}
import argv
import gleam/list
import gleam/result
import gleam/string
import infrastructure.{type DesugaringError, DesugaringError}
import vxml_parser.{type VXML, Blame}
import writerly_parser.{assemble_blamed_lines, parse_blamed_lines, writerlys_to_vxmls}
import pipeline_debug.{pipeline_introspection_lines2string}

const ins = string.inspect

pub const path = "test/content"

fn get_root(vxmls: List(VXML)) -> Result(VXML, DesugaringError) {
  case vxmls {
    [root] -> Ok(root)
    _ ->
      Error(DesugaringError(
        blame: Blame("", 0, []),
        message: "found "
          <> ins(list.length)
          <> " != 1 root-level nodes in "
          <> path,
      ))
  }
}

pub fn desugar_internal(vxml: VXML, pipeline: Pipeline) -> Result(VXML, DesugaringError) {
  case pipeline {
      [] -> Ok(vxml)
      [#(_, desugarer), ..rest] -> {
        result.try(desugarer(vxml), desugar_internal(_, rest))
      }
  }
} 

pub fn desugar(vxmls: List(VXML), pipeline: Pipeline) -> Result(VXML, DesugaringError) {
  case get_root(vxmls) {
    Ok(root) -> desugar_internal(root, pipeline)
    Error(e) -> Error(e)
  }
}

pub fn main() {
  let assert Ok(assembled) = assemble_blamed_lines(path)

  let args = argv.load().arguments
    case args {
      [] -> {
        let assert Ok(writerlys) = parse_blamed_lines(assembled, False)
        let vxmls = writerlys_to_vxmls(writerlys)

        case desugar(vxmls, pipeline_constructor()) {
          Ok(desugared) ->
            vxml_parser.debug_print_vxml("(add attribute desugarer)", desugared)
          Error(err) -> io.println("there was a desugaring error: " <> ins(err))
        }
      }
      [command] ->
        case command {
          "debug" ->{ 
            pipeline_introspection_lines2string(assembled, pipeline_constructor())
            |> io.print()
           }
          _ -> io.println("commands available: debug")
        }
      _ -> io.println("commands available: debug")
    }
}
