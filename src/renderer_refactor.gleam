import gleam/result
import gleam/io
import gleam/list
import gleam/string
import blamedlines.{type BlamedLine}
import vxml_parser.{type VXML}
import infrastructure.{type Pipe, type EitherOr, type DesugaringError, Either, Or} as infra
import gleam/option.{type Option, None, Some}
import pipeline_debug

// *************
// BLAMED LINES ASSEMBLER(a)                 // a is error type of assembler
// file/directory -> List(BlamedLine)
// *************

pub type BlamedLinesAssembler(a) = fn(String) -> Result(List(BlamedLine), a)
  
pub type BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// *************
// SOURCE PARSER(b, c)                      // b is data type of parsed source (Writerly), c is error type of parser
// List(BlamedLines) -> parsed source
// *************

pub type SourceParser(b, c) = fn(List(BlamedLine)) -> Result(b, c)

pub type SourceParserDebugOptions {
  SourceParserDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// *************
// SOURCE_TO_VXML_CONVERTER(b)
// b -> VXML
// *************

pub type SourceToVXMLConverter(b) = fn(b) -> List(VXML)

pub type SourceToVXMLConverterDebugOptions {
  SourceToVXMLConverterDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// *************
// PIPELINE
// VXML -> ... -> VXML
// *************

pub type Pipeline = List(Pipe)

pub type PipelineDebugOptions {
  PipelineDebugOptions(
    debug_print: fn(Int, Pipe) -> Bool,
    artifact_print: fn(Int, Pipe) -> Bool,
    artifact_directory: String,
  )
}

// *************
// SPLITTER(d, e)             // 'd' is fragment type, 'e' is error type for splitting
// VXML -> List(#(VXML, d)) 
// *************

pub type Splitter(d, e) = fn(VXML) -> Result(List(#(VXML, d)), e)

pub type SplitterDebugOptions(d) {
  SplitterDebugOptions(
    debug_print: fn(VXML, d) -> Bool,
    artifact_print: fn(VXML, d) -> Bool,
    artifact_directory: String,
  )
}

// *************
// FRAGMENT EMITTER(d, f)                     // where 'd' is fragment type & 'e' is emitter error type
// #(VXML, d) -> #(String, List(BlamedLine))  // where 'String' is the filepath (f.g., 'chapters/Chapter1.tsx')
// *************

pub type FragmentEmitter(d, f) = fn(#(VXML, d)) -> Result(#(String, List(BlamedLine), d), f)

pub type FragmentEmitterDebugOptions(d) {
  FragmentEmitterDebugOptions(
    debug_print: fn(VXML, d) -> Bool,
    artifact_print: fn(VXML, d) -> Bool,
    artifact_directory: String,
  )
}

// *************
// FRAGMENT PRINTER(g)                 // where 'g' is printing error type (might include prettier error not only simplifile error)
// #(String, List(BlamedLine)) -> Nil
// *************

pub type FragmentPrinter(d, g) = fn(String, #(String, List(BlamedLine), d)) -> Result(String, g)

pub type FragmentPrinterDebugOptions(d) {
  FragmentPrinterDebugOptions(
    debug_print: fn(String, List(BlamedLine), d) -> Bool,
    artifact_print: fn(String, List(BlamedLine), d) -> Bool,
    artifact_directory: String,
  )
}

// *************
// RENDERER(a, b, c, d, e, f, g) -- ALL TOGETHER
// file/directory -> file(s)
// *************

pub type Renderer(
  a, // error type for blamed line assembly
  b, // parsed source type (== Writerly)
  c, // blamed lines -> parsed source parsing error (== WriterlyParseError)
  d, // enum type for VXML Fragment
  e, // splitting error
  f, // fragment emitting error
  g, // fragment printing error
) {
  Renderer(
    assembler: BlamedLinesAssembler(a),
    source_parser: SourceParser(b, c),
    source_converter: SourceToVXMLConverter(b),
    pipeline: List(Pipe),
    splitter: Splitter(d, e),                // VXML -> List(#(VXML, d))
    fragment_emitter: FragmentEmitter(d, f), // #(VXML, d) -> List(BlamedLine)
    fragment_printer: FragmentPrinter(d, g), // List(BlamedLine) & "just prints".... maybe runs prettier!
  )
}

pub type RendererError(a, c, e, f, g) {
  AssemblyError(a)
  SourceParserError(c)
  GetRootError(String)
  PipelineError(DesugaringError)
  SplitterError(e)
  EmittingOrPrintingErrors(List(EitherOr(f, g)))
  ArtifactPrintingError(String)
}

pub type RendererDebugOptions(d) {
  RendererDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    artifact_print_is_debug_print: Bool,
    clear_artifact_directories: List(String),
    assembler_debug_options: BlamedLinesAssemblerDebugOptions,
    source_parser_debug_options: SourceParserDebugOptions,
    source_emitter_debug_options: SourceToVXMLConverterDebugOptions,
    pipeline_debug_options: PipelineDebugOptions,
    splitter_debug_options: SplitterDebugOptions(d),
    emitter_debug_options: FragmentEmitterDebugOptions(d),
    printer_debug_options: FragmentPrinterDebugOptions(d),
  )
}

// a, // error type for blamed line assembly
// b, // parsed source type (== Writerly)
// c, // blamed lines -> parsed source parsing error (== WriterlyParseError)
// d, // enum type for VXML Fragment
// e, // splitting error
// f, // fragment emitting error
// g, // fragment printing error

const ins = string.inspect

fn pipeline_runner(
  vxml: VXML,
  pipeline: List(Pipe),
  pipeline_debug_options: PipelineDebugOptions,
  step: Int,
) -> Result(VXML, DesugaringError) {
  case pipeline {
    [] -> Ok(vxml)
    [#(desugarer_desc, desugarer) as pipe, ..rest] -> {
      case pipeline_debug_options.debug_print(step, pipe) {
        False -> Nil
        True -> io.print(pipeline_debug.desugarer_description_star_block(desugarer_desc, step))
      }

      case desugarer(vxml) {
        Ok(vxml) -> {
          case pipeline_debug_options.debug_print(step, pipe) {
            False -> Nil
            True -> vxml_parser.debug_print_vxml("(" <> ins(step) <> ")", vxml)
          }
          pipeline_runner(vxml, rest, pipeline_debug_options, step + 1)
        }
        Error(error) -> Error(error)
      }
    }
  }
}

pub fn run_renderer(
  input_dir: String,
  renderer: Renderer(a, b, c, d, e, f, g),
  debug_options: RendererDebugOptions(d),
  output_dir: Option(String),
) -> Result(Nil, RendererError(a, c, e, f, g)) {
  use assembled <- infra.on_error_on_ok(
    over: renderer.assembler(input_dir),
    with_on_error: fn(error_a) {
      case debug_options.error_messages {
        True -> io.println("renderer.assembler error: " <> ins(error_a))
        _ -> Nil
      }
      Error(AssemblyError(error_a))
    }
  )

  case debug_options.assembler_debug_options.debug_print {
    False -> Nil
    True -> io.println(blamedlines.blamed_lines_to_table_vanilla_bob_and_jane_sue("(assembled)", assembled))
  }

  use source : b <- infra.on_error_on_ok(
    over: renderer.source_parser(assembled),
    with_on_error: fn(error : c) {
      case debug_options.error_messages {
        True -> io.println("renderer.source_parser error: " <> ins(error))
        _ -> Nil
      }
      Error(SourceParserError(error))
    }
  )

  use converted <- infra.on_error_on_ok(
    over: infra.get_root(renderer.source_converter(source)),
    with_on_error: fn(message: String) {
      case debug_options.error_messages {
        True -> io.println("renderer.get_root(parsed_source): " <> message)
        _ -> Nil
      }
      Error(GetRootError(message))
    }
  )

  use desugared <- infra.on_error_on_ok(
    over: pipeline_runner(converted, renderer.pipeline, debug_options.pipeline_debug_options, 0),
    with_on_error: fn(e: DesugaringError) {
      case debug_options.error_messages {
        True -> io.println(ins(e))
        _ -> Nil
      }
      Error(PipelineError(e))
    }
  )

  use fragments1 <- infra.on_error_on_ok(
    over: renderer.splitter(desugared),
    with_on_error: fn(error: e) {
      case debug_options.error_messages {
        True -> io.println("splitter error: " <> ins(error))
        _ -> Nil
      }
      Error(SplitterError(error))
    }
  )

  let fragments2 = {
    fragments1
    |> list.map(renderer.fragment_emitter)
    |> list.map(
      fn (result) {
        case result {
          Error(error) -> {
            case debug_options.error_messages {
              True -> io.println("emitting error: " <> ins(error))
              _ -> Nil
            }
            Error(Either(error))
          }
          Ok(triple) -> {
            case output_dir {
              None -> Ok(Nil)
              Some(real_dir) -> 
                case renderer.fragment_printer(real_dir, triple) {
                  Error(error) -> {
                    case debug_options.error_messages {
                      True -> io.println("error printing to " <> real_dir <> ": " <> ins(error))
                      _ -> Nil
                    }
                    Error(Or(error))
                  }
                  Ok(path) -> {
                    case debug_options.basic_messages {
                      True -> Ok(io.println("printed " <> path))
                      _ -> Ok(Nil)
                    }
                  }
                }
            }
          }
        }
      }
    )
  }

  let #(_, errors) = result.partition(fragments2)

  case list.length(errors) > 0 {
    False -> Error(EmittingOrPrintingErrors(errors))
    True -> Ok(Nil)
  }
}
