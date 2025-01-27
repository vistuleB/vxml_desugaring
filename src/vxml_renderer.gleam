import blamedlines.{type BlamedLine}
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import infrastructure.{type DesugaringError, type Pipe} as infra
import pipeline_debug
import shellout
import simplifile
import vxml_parser.{type VXML}

const ins = string.inspect

// *************
// BLAMED LINES ASSEMBLER(a)                     // 'a' is assembler error type
// file/directory -> List(BlamedLine)
// *************

pub type BlamedLinesAssembler(a) =
  fn(String) -> Result(List(BlamedLine), a)

pub type BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// *************
// SOURCE PARSER(b, c)                           // 'b' is type of parsed source (Writerly), 'c' is parser error type
// List(BlamedLines) -> parsed source
// *************

pub type SourceParser(b, c) =
  fn(List(BlamedLine)) -> Result(b, c)

pub type SourceParserDebugOptions {
  SourceParserDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// *************
// PARSED SOURCE CONVERTER(b)                    // 'b' is type of parsed source (Writerly)
// b -> List(VXML)
// *************

pub type ParsedSourceConverter(b) =
  fn(b) -> List(VXML)

pub type ParsedSourceConverterDebugOptions {
  ParsedSourceConverterDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// *************
// PIPELINE
// VXML -> ... -> VXML
// *************

pub type Pipeline =
  List(Pipe)

pub type PipelineDebugOptions {
  PipelineDebugOptions(
    debug_print: fn(Int, Pipe) -> Bool,
    artifact_print: fn(Int, Pipe) -> Bool,
    artifact_directory: String,
  )
}

// *************
// SPLITTER(d, e)                                // 'd' is fragment type enum, 'e' is splitter error type
// VXML -> List(#(String, VXML, d))              // #(local_path, vxml, fragment_type)
// *************

pub type Splitter(d, e) =
  fn(VXML) -> Result(List(#(String, VXML, d)), e)

pub type SplitterDebugOptions(d) {
  SplitterDebugOptions(
    debug_print: fn(String, VXML, d) -> Bool,
    artifact_print: fn(String, VXML, d) -> Bool,
    artifact_directory: String,
  )
}

// *************
// EMITTER(d, f)                                         // where 'd' is fragment type & 'f' is emitter error type
// #(String, VXML, d) -> #(String, List(BlamedLine), d)  // #(local_path, blamed_lines, fragment_type)
// *************

pub type Emitter(d, f) =
  fn(#(String, VXML, d)) -> Result(#(String, List(BlamedLine), d), f)

pub type EmitterDebugOptions(d) {
  EmitterDebugOptions(
    debug_print: fn(String, List(BlamedLine), d) -> Bool,
    artifact_print: fn(String, List(BlamedLine), d) -> Bool,
    artifact_directory: String,
  )
}

// *************
// PRINTER
// (no function, only a DebugOption for printing
// what was printed to file before prettifying)
// *************

pub type PrinterDebugOptions(d) {
  PrinterDebugOptions(debug_print: fn(String, d) -> Bool)
}

// *************
// PRETTIFIER(d, g, h)                           // where 'g' is prettifying enum, 'h' is prettifier error type
// String, #(String, d), g -> Result(String, h)  // output_dir, #(local_path, fragment_type), prettifying enum
// *************

pub type Prettifier(d, g, h) =
  fn(String, #(String, d), g) -> Result(String, h)

pub type PrettifierDebugOptions(d, g) {
  PrettifierDebugOptions(debug_print: fn(String, d, g) -> Bool)
}

//********************
// the standard prettifier (for jsx)
//********************

pub fn run_prettier(in: String, path: String) -> Result(String, #(Int, String)) {
  shellout.command(
    run: "npx",
    in: in,
    with: ["prettier", "--write", path],
    opt: [],
  )
}

pub fn prettier_prettifier(
  output_dir: String,
  pair: #(String, d),
  prettify: Bool,
) -> Result(String, #(Int, String)) {
  use <- infra.on_false_on_true(prettify, Ok(""))
  let #(local_path, _) = pair
  run_prettier(".", output_dir <> "/" <> local_path)
  |> result.map(fn(_) { "prettified: " <> local_path })
}

// *************
// RENDERER(a, b, c, d, e, f, g, h)
// *************

pub type Renderer(
  a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  // blamed line assembly error type
  // parsed source type (== Writerly)
  // source parsing error type (== WriterlyParseError)
  // VXML Fragment enum type
  // splitting error type
  // fragment emitting error type
  // prettifying enum type
  // prettifying error type
) {
  Renderer(
    assembler: BlamedLinesAssembler(a),
    // file/directory -> List(BlamedLine)
    source_parser: SourceParser(b, c),
    // List(BlamedLine) -> parsed source
    parsed_source_converter: ParsedSourceConverter(b),
    // parsed source -> List(VXML)
    pipeline: List(Pipe),
    // VXML -> ... -> VXML
    splitter: Splitter(d, e),
    // VXML -> List(#(String, VXML, d))
    emitter: Emitter(d, f),
    // #(String, VXML, d) -> #(String, List(BlamedLine), d)
    prettifier: Prettifier(d, g, h),
    // String, #(String, d), g -> Nil
  )
}

// *************
// RENDERER DEBUG OPTIONS(d)
// *************

pub type RendererDebugOptions(d, g) {
  RendererDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    assembler_debug_options: BlamedLinesAssemblerDebugOptions,
    source_parser_debug_options: SourceParserDebugOptions,
    source_emitter_debug_options: ParsedSourceConverterDebugOptions,
    pipeline_debug_options: PipelineDebugOptions,
    splitter_debug_options: SplitterDebugOptions(d),
    emitter_debug_options: EmitterDebugOptions(d),
    printer_debug_options: PrinterDebugOptions(d),
    prettifier_debug_options: PrettifierDebugOptions(d, g),
  )
}

// *************
// RENDERER PARAMETERS(g)
// *************

pub type RendererParameters(g) {
  RendererParameters(
    input_dir: String,
    output_dir: Option(String),
    prettifying_option: g,
  )
}

// *************
// RENDERER IN-HOUSE HELPER FUNCTIONS
// *************

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
        True ->
          io.print(pipeline_debug.desugarer_description_star_block(
            desugarer_desc,
            step,
          ))
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

pub fn sanitize_output_dir(
  parameters: RendererParameters(g),
) -> RendererParameters(g) {
  let output_dir = case parameters.output_dir {
    None -> None
    Some(string) -> Some(infra.drop_ending_slash(string))
  }

  RendererParameters(
    input_dir: parameters.input_dir,
    output_dir: output_dir,
    prettifying_option: parameters.prettifying_option,
  )
}

pub fn output_dir_local_path_printer(
  output_dir: String,
  local_path: String,
  content: String,
) -> Result(Nil, simplifile.FileError) {
  let assert False = string.starts_with(local_path, "/")
  let assert False = string.ends_with(output_dir, "/")
  let path = output_dir <> "/" <> local_path
  simplifile.write(path, content)
}

pub fn possible_error_message(
  debug_options: RendererDebugOptions(d, g),
  message: String,
) -> Nil {
  case debug_options.error_messages {
    True -> io.println(message)
    _ -> Nil
  }
}

// *************
// RENDERER ERROR(a, c, e, f, h)
// *************

pub type RendererError(a, c, e, f, h) {
  AssemblyError(a)
  SourceParserError(c)
  GetRootError(String)
  PipelineError(DesugaringError)
  SplitterError(e)
  EmittingOrPrintingOrPrettifyingErrors(
    List(ThreePossibilities(f, simplifile.FileError, h)),
  )
  ArtifactPrintingError(String)
}

pub type ThreePossibilities(f, g, h) {
  C1(f)
  C2(g)
  C3(h)
}

// *************
// RUN_RENDERER
// *************

pub fn run_renderer(
  renderer: Renderer(a, b, c, d, e, f, g, h),
  parameters: RendererParameters(g),
  debug_options: RendererDebugOptions(d, g),
) -> Result(Nil, RendererError(a, c, e, f, h)) {
  io.println("")

  let parameters = sanitize_output_dir(parameters)

  use assembled <- infra.on_error_on_ok(
    over: renderer.assembler(parameters.input_dir),
    with_on_error: fn(error_a) {
      case debug_options.error_messages {
        True -> io.println("renderer.assembler error: " <> ins(error_a))
        _ -> Nil
      }
      Error(AssemblyError(error_a))
    },
  )

  case debug_options.assembler_debug_options.debug_print {
    False -> Nil
    True ->
      io.println(blamedlines.blamed_lines_to_table_vanilla_bob_and_jane_sue(
        "(assembled)",
        assembled,
      ))
  }

  use source: b <- infra.on_error_on_ok(
    over: renderer.source_parser(assembled),
    with_on_error: fn(error: c) {
      case debug_options.error_messages {
        True -> io.println("renderer.source_parser error: " <> ins(error))
        _ -> Nil
      }
      Error(SourceParserError(error))
    },
  )

  use converted <- infra.on_error_on_ok(
    over: infra.get_root(renderer.parsed_source_converter(source)),
    with_on_error: fn(message: String) {
      case debug_options.error_messages {
        True -> io.println("renderer.get_root(parsed_source): " <> message)
        _ -> Nil
      }
      Error(GetRootError(message))
    },
  )

  use desugared <- infra.on_error_on_ok(
    over: pipeline_runner(
      converted,
      renderer.pipeline,
      debug_options.pipeline_debug_options,
      0,
    ),
    with_on_error: fn(e: DesugaringError) {
      case debug_options.error_messages {
        True -> io.println(ins(e))
        _ -> Nil
      }
      Error(PipelineError(e))
    },
  )

  // vxml fragments generation
  use fragments <- infra.on_error_on_ok(
    over: renderer.splitter(desugared),
    with_on_error: fn(error: e) {
      possible_error_message(debug_options, "splitter error: " <> ins(error))
      Error(SplitterError(error))
    },
  )

  // vxml fragments -> blamed line fragments
  let fragments =
    fragments
    |> list.map(renderer.emitter)

  // blamed line fragments debug printing
  fragments
  |> list.each(fn(result) {
    case result {
      Error(_) -> Nil
      Ok(#(local_path, blamed_lines, fragment_type)) -> {
        case
          debug_options.emitter_debug_options.debug_print(
            local_path,
            blamed_lines,
            fragment_type,
          )
        {
          False -> Nil
          True -> {
            blamedlines.blamed_lines_to_table_vanilla_bob_and_jane_sue(
              "(emitter_debug_options:" <> local_path <> ")",
              blamed_lines,
            )
            |> io.println
          }
        }
      }
    }
  })

  // blamed line fragments -> string fragments
  let fragments = {
    fragments
    |> list.map(fn(result) {
      case result {
        Error(error) -> {
          possible_error_message(
            debug_options,
            "emitting error: " <> ins(error),
          )
          Error(C1(error))
        }
        Ok(#(local_path, lines, fragment_type)) -> {
          Ok(#(
            local_path,
            blamedlines.blamed_lines_to_string(lines),
            fragment_type,
          ))
        }
      }
    })
  }

  // string fragments debug printing
  fragments
  |> list.each(fn(result) {
    case result {
      Error(_) -> Nil
      Ok(#(local_path, content, fragment_type)) -> {
        case
          debug_options.printer_debug_options.debug_print(
            local_path,
            fragment_type,
          )
        {
          False -> Nil
          True -> {
            let header =
              "----------------- printer_debug_options: "
              <> local_path
              <> " -----------------"
            io.println(header)
            io.println(content)
            io.println(string.repeat("-", string.length(header)))
            io.println("")
          }
        }
      }
    }
  })

  // printing string fragments (list.map to record errors)
  let fragments =
    fragments
    |> list.map(fn(result) {
      use triple <- result.then(result)
      let #(local_path, content, fragment_type) = triple
      use output_dir <- infra.on_none_on_some(
        parameters.output_dir,
        Ok(#(local_path, fragment_type)),
      )
      case output_dir_local_path_printer(output_dir, local_path, content) {
        Ok(Nil) -> {
          case debug_options.basic_messages {
            False -> Nil
            True -> io.println("printed: " <> local_path)
          }
          Ok(#(local_path, fragment_type))
        }
        Error(file_error) -> Error(C2(file_error))
      }
    })

  // running prettifier (list.map to record erros)
  let fragments =
    fragments
    |> list.map(fn(result) {
      use #(local_path, fragment_type) <- result.then(result)
      use output_dir <- infra.on_none_on_some(parameters.output_dir, result)
      case
        renderer.prettifier(
          output_dir,
          #(local_path, fragment_type),
          parameters.prettifying_option,
        )
      {
        Error(e) -> Error(C3(e))
        Ok(message) -> {
          case debug_options.basic_messages && message != "" {
            False -> Nil
            True -> io.println(message)
          }
          result
        }
      }
    })

  // prettified fragments debug printing
  fragments
  |> list.each(fn(result) {
    use #(local_path, fragment_type) <- infra.on_error_on_ok(result, fn(_) {
      Nil
    })
    use output_dir <- infra.on_none_on_some(parameters.output_dir, Nil)
    case
      debug_options.prettifier_debug_options.debug_print(
        local_path,
        fragment_type,
        parameters.prettifying_option,
      )
    {
      False -> Nil
      True -> {
        let path = output_dir <> "/" <> local_path
        use file_contents <- infra.on_error_on_ok(
          simplifile.read(path),
          fn(error) {
            io.println(
              "\ncould not read back printed file " <> path <> ":" <> ins(error),
            )
          },
        )
        io.println("")
        let header =
          "----------------- printer_debug_options: "
          <> local_path
          <> " -----------------"
        io.println(header)
        io.println(file_contents)
        io.println(string.repeat("-", string.length(header)))
        io.println("")
      }
    }
  })

  let #(_, errors) = result.partition(fragments)

  case list.length(errors) > 0 {
    True -> Error(EmittingOrPrintingOrPrettifyingErrors(errors))
    False -> Ok(Nil)
  }
}

//********************
// COMMAND-LINE PROCESSING (generic --key val1 val2 ... functions)
//********************

fn take_strings_while_not_key(
  upcoming: List(String),
  bundled: List(String),
) -> #(List(String), List(String)) {
  case upcoming {
    [] -> #(bundled |> list.reverse, upcoming)
    [first, ..rest] -> {
      case string.starts_with(first, "--") {
        True -> #(bundled |> list.reverse, upcoming)
        False -> take_strings_while_not_key(rest, [first, ..bundled])
      }
    }
  }
}

pub fn double_dash_keys(
  arguments: List(String),
) -> Result(List(#(String, List(String))), String) {
  case arguments {
    [] -> Ok([])
    [first, ..rest] -> {
      case string.starts_with(first, "--") {
        False -> Error(first)
        True -> {
          let #(arg_values, rest) = take_strings_while_not_key(rest, [])
          case double_dash_keys(rest) {
            Error(e) -> Error(e)
            Ok(parsed) -> Ok([#(first, arg_values), ..parsed])
          }
        }
      }
    }
  }
}

//********************
// COMMAND LINE AMENDMENTS
//********************

pub type CommandLineAmendments(
  g,
  // prettifying enum
) {
  CommandLineAmendments(
    input_dir: Option(String),
    output_dir: Option(String),
    prettifying_option: Option(g),
    debug_pipeline_range: #(Int, Int),
    debug_pipeline_desugarer_names: List(String),
    basic_messages: Bool,
    debug_blamed_lines_fragments_local_paths: List(String),
    debug_printed_string_fragments_local_paths: List(String),
    debug_prettified_string_fragments_local_paths: List(String),
  )
}

//********************
// BUILDING COMMAND LINE AMENDMENTS FROM COMMAND LINE ARGS
//********************

pub fn empty_command_line_amendments() -> CommandLineAmendments(g) {
  CommandLineAmendments(
    input_dir: None,
    output_dir: None,
    prettifying_option: None,
    debug_pipeline_range: #(-1, -1),
    debug_pipeline_desugarer_names: [],
    basic_messages: True,
    debug_blamed_lines_fragments_local_paths: [],
    debug_printed_string_fragments_local_paths: [],
    debug_prettified_string_fragments_local_paths: [],
  )
}

fn amend_prettifying_option(
  amendment: CommandLineAmendments(g),
  val: g,
) -> CommandLineAmendments(g) {
  CommandLineAmendments(
    amendment.input_dir,
    amendment.output_dir,
    Some(val),
    amendment.debug_pipeline_range,
    amendment.debug_pipeline_desugarer_names,
    amendment.basic_messages,
    amendment.debug_blamed_lines_fragments_local_paths,
    amendment.debug_printed_string_fragments_local_paths,
    amendment.debug_prettified_string_fragments_local_paths,
  )
}

fn amend_debug_pipeline_range(
  amendment: CommandLineAmendments(a),
  start: Int,
  end: Int,
) -> CommandLineAmendments(a) {
  CommandLineAmendments(
    amendment.input_dir,
    amendment.output_dir,
    amendment.prettifying_option,
    #(start, end),
    amendment.debug_pipeline_desugarer_names,
    amendment.basic_messages,
    amendment.debug_blamed_lines_fragments_local_paths,
    amendment.debug_printed_string_fragments_local_paths,
    amendment.debug_prettified_string_fragments_local_paths,
  )
}

fn amend_debug_pipeline_desugarer_names(
  amendment: CommandLineAmendments(a),
  names: List(String),
) -> CommandLineAmendments(a) {
  CommandLineAmendments(
    amendment.input_dir,
    amendment.output_dir,
    amendment.prettifying_option,
    amendment.debug_pipeline_range,
    list.append(amendment.debug_pipeline_desugarer_names, names),
    amendment.basic_messages,
    amendment.debug_blamed_lines_fragments_local_paths,
    amendment.debug_printed_string_fragments_local_paths,
    amendment.debug_prettified_string_fragments_local_paths,
  )
}

pub fn amend_debug_blamed_lines_fragments_local_paths(
  amendment: CommandLineAmendments(a),
  names: List(String),
) -> CommandLineAmendments(a) {
  CommandLineAmendments(
    amendment.input_dir,
    amendment.output_dir,
    amendment.prettifying_option,
    amendment.debug_pipeline_range,
    amendment.debug_pipeline_desugarer_names,
    amendment.basic_messages,
    list.append(amendment.debug_blamed_lines_fragments_local_paths, names),
    amendment.debug_printed_string_fragments_local_paths,
    amendment.debug_prettified_string_fragments_local_paths,
  )
}

fn amend_debug_printed_string_fragments_local_paths(
  amendment: CommandLineAmendments(a),
  names: List(String),
) -> CommandLineAmendments(a) {
  CommandLineAmendments(
    amendment.input_dir,
    amendment.output_dir,
    amendment.prettifying_option,
    amendment.debug_pipeline_range,
    amendment.debug_pipeline_desugarer_names,
    amendment.basic_messages,
    amendment.debug_blamed_lines_fragments_local_paths,
    list.append(amendment.debug_printed_string_fragments_local_paths, names),
    amendment.debug_prettified_string_fragments_local_paths,
  )
}

fn amend_debug_prettified_string_fragments_local_paths(
  amendment: CommandLineAmendments(a),
  names: List(String),
) -> CommandLineAmendments(a) {
  CommandLineAmendments(
    amendment.input_dir,
    amendment.output_dir,
    amendment.prettifying_option,
    amendment.debug_pipeline_range,
    amendment.debug_pipeline_desugarer_names,
    amendment.basic_messages,
    amendment.debug_blamed_lines_fragments_local_paths,
    amendment.debug_printed_string_fragments_local_paths,
    list.append(amendment.debug_prettified_string_fragments_local_paths, names),
  )
}

pub fn cli_usage() {
  io.println("command line options (mix & match any combination):")
  io.println("")
  io.println("      --spotlight <path1> <path2> ...")
  io.println("         -> spotlight the given paths before assembling")
  io.println("      --debug-pipeline-<x>-<y>")
  io.println("         -> print output of pipes number x up to y")
  io.println("      --debug-pipeline-<x>")
  io.println("         -> print output of pipe number x")
  io.println("      --debug-pipeline-0-0")
  io.println("         -> print output of all pipes")
  io.println("      --debug-fragments-bl <local_path1> <local_path2> ...")
  io.println("         -> print blamed lines of local paths")
  io.println("      --debug-fragments-printed <local_path1> <local_path2> ...")
  io.println("         -> print unprettified output files of local paths")
  io.println("      --debug-fragments-prettified <local_path1> <local_path2> ...")
  io.println("         -> print prettified output files of local paths")
}

pub type CommandLineError {
  ExpectedDoubleDashString(String)
  UnwantedOptionArgument(String)
  ErrorRunningSpotlight(Int, String)
  BadDebugPipelineRange(String)
}

pub fn process_command_line_arguments(
  arguments: List(String),
  prettier_options: List(#(String, g)),
) -> Result(CommandLineAmendments(g), CommandLineError) {
  use list_key_values <- infra.on_error_on_ok(
    double_dash_keys(arguments),
    fn(bad_key) { Error(ExpectedDoubleDashString(bad_key)) },
  )

  let prettier_options_dict = dict.from_list(prettier_options)

  list_key_values
  |> list.fold(Ok(empty_command_line_amendments()), fn(result, pair) {
    use amendment <- result.then(result)
    let #(option, values) = pair
    case option {
      "--debug-fragments-bl" -> {
        Ok(amendment |> amend_debug_blamed_lines_fragments_local_paths(values))
      }
      "--debug-fragments-printed" -> {
        Ok(
          amendment |> amend_debug_printed_string_fragments_local_paths(values),
        )
      }
      "--debug-fragments-prettified" -> {
        Ok(
          amendment
          |> amend_debug_prettified_string_fragments_local_paths(values),
        )
      }
      "--spotlight" -> {
        case
          shellout.command(run: "./spotlight", in: ".", with: values, opt: [])
        {
          Ok(_) -> Ok(amendment)
          Error(#(code, message)) -> {
            io.println(
              "shellout error running spotlight: " <> ins(#(code, message)),
            )
            Error(ErrorRunningSpotlight(code, message))
          }
        }
      }
      "--debug-pipeline" -> {
        case list.is_empty(values) {
          True -> Ok(amendment |> amend_debug_pipeline_range(0, 0))
          False -> Ok(amendment |> amend_debug_pipeline_desugarer_names(values))
        }
      }
      _ -> {
        case string.starts_with(option, "--debug-pipeline-") {
          True -> {
            let suffix =
              string.drop_start(option, string.length("--debug-pipeline-"))
            let pieces = string.split(suffix, "-")
            case list.length(pieces) {
              2 -> {
                let assert [b, c] = pieces
                case int.parse(b), int.parse(c) {
                  Ok(debug_start), Ok(debug_end) -> {
                    Ok(
                      amendment
                      |> amend_debug_pipeline_range(debug_start, debug_end),
                    )
                  }
                  _, _ -> Error(BadDebugPipelineRange(option))
                }
              }
              1 -> {
                let assert [b] = pieces
                case int.parse(b) {
                  Ok(debug_start) -> {
                    Ok(
                      amendment
                      |> amend_debug_pipeline_range(debug_start, debug_start),
                    )
                  }
                  _ -> Error(BadDebugPipelineRange(option))
                }
              }
              _ -> Error(BadDebugPipelineRange(option))
            }
          }
          False -> {
            case dict.get(prettier_options_dict, option) {
              Error(Nil) -> Error(UnwantedOptionArgument(option))
              Ok(prettifying_option) -> {
                case values {
                  [] ->
                    Ok(
                      amendment |> amend_prettifying_option(prettifying_option),
                    )
                  [first, ..] -> Error(UnwantedOptionArgument(first))
                }
              }
            }
          }
        }
      }
    }
  })
}

//********************
// AMENDING RENDERER PARAMETERS BY COMMAND LINE AMENDMENTS
//********************

fn pr_amend_input_dir(
  input_dir: String,
  amendments: CommandLineAmendments(g),
) -> String {
  case amendments.input_dir {
    None -> input_dir
    Some(other) -> other
  }
}

fn pr_amend_output_dir(
  output_dir: Option(String),
  amendments: CommandLineAmendments(g),
) -> Option(String) {
  case amendments.input_dir {
    None -> output_dir
    Some(other) -> Some(other)
  }
}

fn pr_amend_prettifying_option(
  prettifying_option: g,
  amendments: CommandLineAmendments(g),
) -> g {
  case amendments.prettifying_option {
    None -> prettifying_option
    Some(other) -> other
  }
}

pub fn amend_renderer_paramaters_by_command_line_amendment(
  parameters: RendererParameters(g),
  amendments: CommandLineAmendments(g),
) -> RendererParameters(g) {
  RendererParameters(
    pr_amend_input_dir(parameters.input_dir, amendments),
    pr_amend_output_dir(parameters.output_dir, amendments),
    pr_amend_prettifying_option(parameters.prettifying_option, amendments),
  )
}

//********************
// AMENDING RENDERER DEBUG OPTIONS BY COMMAND LINE AMENDMENTS
//********************

pub fn db_amend_pipeline_debug_options(
  options: PipelineDebugOptions,
  amendments: CommandLineAmendments(b),
) -> PipelineDebugOptions {
  let PipelineDebugOptions(_, artifact_print, artifact_directory) = options

  let #(start, end) = amendments.debug_pipeline_range
  let names = amendments.debug_pipeline_desugarer_names

  PipelineDebugOptions(
    fn(step, pipe) {
      { start == 0 && end == 0 }
      || { start <= step && step <= end }
      || {
        list.is_empty(names) == False
        && {
          let #(description, _) = pipe
          list.contains(names, description.function_name)
        }
      }
    },
    artifact_print,
    artifact_directory,
  )
}

pub fn db_amend_emitter_debug_options(
  options: EmitterDebugOptions(a),
  amendments: CommandLineAmendments(b),
) -> EmitterDebugOptions(a) {
  let EmitterDebugOptions(
    previous_condition,
    artifact_print,
    artifact_directory,
  ) = options

  EmitterDebugOptions(
    fn(local_path, lines, fragment_type) {
      previous_condition(local_path, lines, fragment_type)
      || list.contains(
        amendments.debug_blamed_lines_fragments_local_paths,
        local_path,
      )
    },
    artifact_print,
    artifact_directory,
  )
}

pub fn db_amend_printed_debug_options(
  options: PrinterDebugOptions(d),
  amendments: CommandLineAmendments(g),
) -> PrinterDebugOptions(d) {
  let PrinterDebugOptions(previous_condition) = options

  PrinterDebugOptions(fn(local_path, fragment_type) {
    {
      previous_condition(local_path, fragment_type)
      || list.contains(
        amendments.debug_printed_string_fragments_local_paths,
        local_path,
      )
    }
  })
}

pub fn db_amend_prettifier_debug_options(
  options: PrettifierDebugOptions(d, g),
  amendments: CommandLineAmendments(g),
) -> PrettifierDebugOptions(d, g) {
  let PrettifierDebugOptions(previous_condition) = options

  PrettifierDebugOptions(fn(local_path, fragment_type, prettifying_enum) {
    {
      previous_condition(local_path, fragment_type, prettifying_enum)
      || list.contains(
        amendments.debug_prettified_string_fragments_local_paths,
        local_path,
      )
    }
  })
}

pub fn amend_renderer_debug_options_by_command_line_amendment(
  debug_options: RendererDebugOptions(d, g),
  amendments: CommandLineAmendments(g),
) -> RendererDebugOptions(d, g) {
  RendererDebugOptions(
    debug_options.basic_messages,
    debug_options.error_messages,
    debug_options.assembler_debug_options,
    debug_options.source_parser_debug_options,
    debug_options.source_emitter_debug_options,
    db_amend_pipeline_debug_options(
      debug_options.pipeline_debug_options,
      amendments,
    ),
    debug_options.splitter_debug_options,
    db_amend_emitter_debug_options(
      debug_options.emitter_debug_options,
      amendments,
    ),
    db_amend_printed_debug_options(
      debug_options.printer_debug_options,
      amendments,
    ),
    db_amend_prettifier_debug_options(
      debug_options.prettifier_debug_options,
      amendments,
    ),
  )
}

//********************
// EMPTY RENDERER DEBUG OPTIONS
//********************

pub fn empty_assembler_debug_options(
  artifact_directory: String,
) -> BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    debug_print: False,
    artifact_print: False,
    artifact_directory: artifact_directory,
  )
}

pub fn empty_source_parser_debug_options(
  artifact_directory: String,
) -> SourceParserDebugOptions {
  SourceParserDebugOptions(
    debug_print: False,
    artifact_print: False,
    artifact_directory: artifact_directory,
  )
}

pub fn empty_source_emitter_debug_options(
  artifact_directory: String,
) -> ParsedSourceConverterDebugOptions {
  ParsedSourceConverterDebugOptions(
    debug_print: True,
    artifact_print: False,
    artifact_directory: artifact_directory,
  )
}

pub fn empty_pipeline_debug_options(
  artifact_directory: String,
) -> PipelineDebugOptions {
  PipelineDebugOptions(
    debug_print: fn(_step, _pipe) { False },
    artifact_print: fn(_step, _pipe) { False },
    artifact_directory: artifact_directory,
  )
}

pub fn empty_splitter_debug_options(
  artifact_directory: String,
) -> SplitterDebugOptions(d) {
  SplitterDebugOptions(
    debug_print: fn(_local_path, _vxml, _fragment_type) { False },
    artifact_print: fn(_local_path, _vxml, _fragment_type) { False },
    artifact_directory: artifact_directory,
  )
}

pub fn empty_emitter_debug_options(
  artifact_directory: String,
) -> EmitterDebugOptions(d) {
  EmitterDebugOptions(
    debug_print: fn(_local_path, _lines, _fragment_type: d) { False },
    artifact_print: fn(_local_path, _lines, _fragment_type: d) { False },
    artifact_directory: artifact_directory,
  )
}

pub fn empty_printer_debug_options() -> PrinterDebugOptions(d) {
  PrinterDebugOptions(debug_print: fn(_local_path, _fragment_type: d) { False })
}

pub fn empty_prettifier_debug_options() -> PrettifierDebugOptions(d, g) {
  PrettifierDebugOptions(
    debug_print: fn(_local_path, _fragment_type, _prettifying_option) { False },
  )
}

pub fn empty_renderer_debug_options(
  artifact_directory: String,
) -> RendererDebugOptions(d, g) {
  RendererDebugOptions(
    basic_messages: True,
    error_messages: True,
    assembler_debug_options: empty_assembler_debug_options(artifact_directory),
    source_parser_debug_options: empty_source_parser_debug_options(
      artifact_directory,
    ),
    source_emitter_debug_options: empty_source_emitter_debug_options(
      artifact_directory,
    ),
    pipeline_debug_options: empty_pipeline_debug_options(artifact_directory),
    splitter_debug_options: empty_splitter_debug_options(artifact_directory),
    emitter_debug_options: empty_emitter_debug_options(artifact_directory),
    printer_debug_options: empty_printer_debug_options(),
    prettifier_debug_options: empty_prettifier_debug_options(),
  )
}
