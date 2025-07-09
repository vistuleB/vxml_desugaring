import gleam/float
import gleam/time/duration
import blamedlines.{type Blame, type BlamedLine, Blame, BlamedLine} as bl
import desugarers/filter_nodes_by_attributes.{filter_nodes_by_attributes}
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string.{inspect as ins}
import infrastructure.{type InSituDesugaringError, InSituDesugaringError, type Desugarer} as infra
import star_block
import shellout
import simplifile
import vxml.{type VXML, V} as vp
import writerly as wp
import gleam/time/timestamp

// *************
// SOURCE ASSEMBLER(a)                             // 'a' is assembler error type
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
// SOURCE PARSER(c)                                // 'c' is parser error type
// List(BlamedLines) -> parsed source
// *************

pub type SourceParser(c) =
  fn(List(BlamedLine)) -> Result(VXML, c)

pub type SourceParserDebugOptions {
  SourceParserDebugOptions(
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
  )
}

// ******************************
// default source parsers
// ******************************

pub fn default_writerly_source_parser(
  lines: List(BlamedLine),
  spotlight_args: List(#(String, String, String)),
) -> Result(VXML, RendererError(a, String, c, d, e)) {
  use writerlys <- result.try(
    wp.parse_blamed_lines(lines)
    |> result.map_error(fn(e) { SourceParserError(ins(e)) }),
  )

  use vxml <- result.try(
    wp.writerlys_to_vxmls(writerlys)
    |> infra.get_root
    |> result.map_error(SourceParserError),
  )

  use filtered_vxml <- result.try(
    filter_nodes_by_attributes(spotlight_args).transform(vxml)
    |> result.map_error(fn(e) { SourceParserError(ins(e)) }),
  )

  Ok(filtered_vxml)
}

pub fn default_html_source_parser(
  lines: List(BlamedLine),
  spotlight_args: List(#(String, String, String)),
) -> Result(VXML, RendererError(a, String, b, c, d)) {
  let path = bl.first_blame_filename(lines) |> result.unwrap("")

  use vxml <- result.try(
    bl.blamed_lines_to_string(lines)
    |> vp.xmlm_based_html_parser(path)
    |> result.map_error(fn(e) {
      case e {
        vp.XMLMIOError(s) -> SourceParserError(s)
        vp.XMLMParseError(s) -> SourceParserError(s)
      }
    }),
  )

  filter_nodes_by_attributes(spotlight_args).transform(vxml)
  |> result.map_error(fn(e: infra.DesugaringError) { SourceParserError(e.message) })
}

// *************
// PIPELINE
// VXML -> ... -> VXML
// *************

pub type Pipeline =
  List(Desugarer)

pub type PipelineDebugOptions {
  PipelineDebugOptions(
    debug_print: fn(Int, Desugarer) -> Bool,
    artifact_print: fn(Int, Desugarer) -> Bool,
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

// ************************
// stub (empty) splitter
// ************************

pub fn empty_splitter(
  vxml: VXML,
  suffix: String,
) -> Result(List(#(String, VXML, Nil)), Nil) {
  let assert V(_, tag, _, _) = vxml
  Ok([#(tag <> suffix, vxml, Nil)])
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

// *****************
// stub html emitter
// *****************

pub fn stub_html_emitter(
  tuple: #(String, VXML, a),
) -> Result(#(String, List(BlamedLine), a), b) {
  let #(path, fragment, fragment_type) = tuple
  let blame_us = fn(msg: String) -> Blame { Blame(msg, 0, 0, []) }
  let lines =
    list.flatten([
      [
        BlamedLine(blame_us("stub_html_emitter"), 0, "<!DOCTYPE html>"),
        BlamedLine(blame_us("stub_html_emitter"), 0, "<html>"),
        BlamedLine(blame_us("stub_html_emitter"), 0, "<head>"),
        BlamedLine(blame_us("stub_html_emitter"), 2, "<link rel=\"icon\" type=\"image/x-icon\" href=\"logo.png\">"),
        BlamedLine(blame_us("stub_html_emitter"), 2, "<meta charset=\"utf-8\">"),
        BlamedLine(blame_us("stub_html_emitter"), 2, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"),
        BlamedLine(blame_us("stub_html_emitter"), 2, "<script type=\"text/javascript\" src=\"./mathjax_setup.js\"></script>"),
        BlamedLine(blame_us("stub_html_emitter"), 2, "<script type=\"text/javascript\" id=\"MathJax-script\" async src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js\"></script>"),
        BlamedLine(blame_us("stub_html_emitter"), 0, "</head>"),
        BlamedLine(blame_us("stub_html_emitter"), 0, "<body>"),
      ],
      fragment
        |> infra.get_children
        |> list.map(fn(vxml) { vp.vxml_to_html_blamed_lines(vxml, 2, 2) })
        |> list.flatten,
      [
        BlamedLine(blame_us("stub_html_emitter"), 0, "</body>"),
        BlamedLine(blame_us("stub_html_emitter"), 0, ""),
      ],
    ])
  Ok(#(path, lines, fragment_type))
}

pub fn stub_jsx_emitter(
  tuple: #(String, VXML, a),
) -> Result(#(String, List(BlamedLine), a), b) {
  let #(path, fragment, fragment_type) = tuple
  let blame_us = fn(msg: String) -> Blame { Blame(msg, 0, 0,[]) }
  let lines =
    list.flatten([
      [
        BlamedLine(
          blame_us("panel_emitter"),
          0,
          "import Something from \"./Somewhere\";",
        ),
        BlamedLine(blame_us("panel_emitter"), 0, ""),
        BlamedLine(
          blame_us("panel_emitter"),
          0,
          "const OurSuperComponent = () => {",
        ),
        BlamedLine(blame_us("panel_emitter"), 2, "return ("),
        BlamedLine(blame_us("panel_emitter"), 4, "<>"),
      ],
      vp.vxmls_to_jsx_blamed_lines(fragment |> infra.get_children, 6),
      [
        BlamedLine(blame_us("panel_emitter"), 4, "</>"),
        BlamedLine(blame_us("panel_emitter"), 2, ");"),
        BlamedLine(blame_us("panel_emitter"), 0, "};"),
        BlamedLine(blame_us("panel_emitter"), 0, ""),
        BlamedLine(
          blame_us("panel_emitter"),
          0,
          "export default OurSuperComponent;",
        ),
      ],
    ])
  Ok(#(path, lines, fragment_type))
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
// PRETTIFIER(d, h)                              // where 'd' is fragment type, 'h' is prettifier error type
// String, #(String, d) -> Result(String, h)     // output_dir, #(local_path, fragment_type)
// *************

pub type Prettifier(d, h) =
  fn(String, #(String, d)) -> Result(String, h)

pub type PrettifierDebugOptions(d) {
  PrettifierDebugOptions(debug_print: fn(String, d) -> Bool)
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
) -> Result(String, #(Int, String)) {
  let #(local_path, _) = pair
  run_prettier(".", output_dir <> "/" <> local_path)
  |> result.map(fn(_) { "prettified: [" <> output_dir <> "/]" <> local_path })
}

pub fn guarded_prettier_prettifier(
  user_args: Dict(String, _),
) -> fn(String, #(String, d)) -> Result(String, #(Int, String)) {
  case dict.get(user_args, "--prettier") {
    Error(Nil) -> fn(_, _) { Ok("") }
    Ok(_) -> prettier_prettifier
  }
}

pub fn empty_prettifier(_: String, _: #(String, d)) -> Result(String, Nil) {
  Ok("")
}

// *************
// RENDERER(a, b, c, d, e, f, g, h)
// *************

pub type Renderer(
  a, // blamed line assembly error type
  c, // source parsing error type
  d, // VXML Fragment enum type
  e, // splitting error type
  f, // fragment emitting error type
  h, // prettifying error type
) {
  Renderer(
    assembler: BlamedLinesAssembler(a), // file/directory -> List(BlamedLine)                     Result w/ error type a
    source_parser: SourceParser(c),     // List(BlamedLine) -> VXML                               Result w/ error type c
    pipeline: List(Desugarer),               // VXML -> ... -> VXML                                    Result w/ error type DesugaringError
    splitter: Splitter(d, e),           // VXML -> List(#(String, VXML, d))                       Result w/ error type e
    emitter: Emitter(d, f),             // #(String, VXML, d) -> #(String, List(BlamedLine), d)   Result w/ error type f
    prettifier: Prettifier(d, h),       // String, #(String, d) -> Nil                            Result w/ error type h
  )
}

// *************
// RENDERER DEBUG OPTIONS(d)
// *************

pub type RendererDebugOptions(d) {
  RendererDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    assembler_debug_options: BlamedLinesAssemblerDebugOptions,
    source_parser_debug_options: SourceParserDebugOptions,
    pipeline_debug_options: PipelineDebugOptions,
    splitter_debug_options: SplitterDebugOptions(d),
    emitter_debug_options: EmitterDebugOptions(d),
    printer_debug_options: PrinterDebugOptions(d),
    prettifier_debug_options: PrettifierDebugOptions(d),
  )
}

// *************
// RENDERER PARAMETERS(g)
// *************

pub type RendererParameters {
  RendererParameters(input_dir: String, output_dir: Option(String))
}

// *************
// RENDERER IN-HOUSE HELPER FUNCTIONS
// *************

fn pipeline_runner(
  vxml: VXML,
  pipeline: List(Desugarer),
  pipeline_debug_options: PipelineDebugOptions,
  step: Int,
) -> Result(VXML, InSituDesugaringError) {
  case pipeline {
    [] -> Ok(vxml)

    [pipe, ..rest] -> {
      case pipeline_debug_options.debug_print(step, pipe) {
        False -> Nil
        True ->
          star_block.desugarer_description_star_block(
            pipe,
            step,
          )
          |> io.print
      }
  
      case pipe.transform(vxml) {
        Ok(vxml) -> {
          case pipeline_debug_options.debug_print(step, pipe) {
            False -> Nil
            True -> vp.debug_print_vxml("(" <> ins(step) <> ")", vxml)
          }
          pipeline_runner(vxml, rest, pipeline_debug_options, step + 1)
        }

        Error(error) -> Error(InSituDesugaringError(
          desugarer: pipe,
          pipeline_step: step,
          blame: error.blame, 
          message: error.message,
        ))
      }
    }
  }
}

pub fn sanitize_output_dir(parameters: RendererParameters) -> RendererParameters {
  let output_dir = case parameters.output_dir {
    None -> None
    Some(string) -> Some(infra.drop_ending_slash(string))
  }

  RendererParameters(input_dir: parameters.input_dir, output_dir: output_dir)
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
  debug_options: RendererDebugOptions(d),
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
  PipelineError(InSituDesugaringError)
  SplitterError(e)
  EmittingOrPrintingOrPrettifyingErrors(List(ThreePossibilities(f, String, h)))
  ArtifactPrintingError(String)
}

pub type ThreePossibilities(f, g, h) {
  C1(f)
  C2(g)
  C3(h)
}

fn quick_message(thing: a, msg: String) -> a {
  io.println(msg)
  thing
}

fn pipeline_overview(pipes: List(Desugarer)) {
  let number_columns = 4
  let name_columns = 70
  let max_param_cols = 40
  let separator = ""
  let none_param = ""

  io.println("ur pipeline is:\n")

  io.println(
    "#."
    <> string.repeat(" ", number_columns - 2)
    <> separator
    <> " NAME"
    <> string.repeat(" ", name_columns - 5)
    <> separator
    <> " PARAM"
  )

  io.println(
    string.repeat("-", 2 + number_columns + name_columns + 20)
  )

  list.index_map(
    pipes,
    fn (pipe, i) {
      let param = case pipe.stringified_param {
        None -> none_param
        Some(thing) -> thing
      }
      let name = pipe.name
      let num = ins(i + 1) <> "."
      let num_spaces = number_columns - string.length(num)
      let name_spaces = name_columns - {1 + string.length(name)}
      let param = case string.length(param) > max_param_cols {
        False -> param
        True -> {
          let excess = string.length(param) - max_param_cols
          string.drop_end(param, excess + 3) <> "..."
        }
      }
      io.println(
        num
        <> string.repeat(" ", num_spaces)
        <> separator
        <> " "
        <> name
        <> string.repeat(" ", name_spaces)
        <> separator
        <> " "
        <> param
      )
    }
  )

  io.println("")
}

// *************
// RUN_RENDERER
// *************

pub fn run_renderer(
  renderer: Renderer(a, c, d, e, f, h),
  parameters: RendererParameters,
  debug_options: RendererDebugOptions(d),
) -> Result(Nil, RendererError(a, c, e, f, h)) {
  io.println("")

  let parameters = sanitize_output_dir(parameters)

  pipeline_overview(renderer.pipeline)

  io.println("-- assembling blamed lines (" <> parameters.input_dir <> ")")

  use assembled <- infra.on_error_on_ok(
    renderer.assembler(parameters.input_dir),
    fn(error_a) {
      case debug_options.error_messages {
        True ->
          io.println(
            "renderer.assembler error on input_dir "
            <> parameters.input_dir
            <> ": "
            <> ins(error_a),
          )
        _ -> Nil
      }
      Error(AssemblyError(error_a))
    },
  )

  case debug_options.assembler_debug_options.debug_print {
    False -> Nil
    True -> {
      io.println(bl.blamed_lines_to_table_vanilla_bob_and_jane_sue(
        "(assembled)",
        assembled,
      ))
    }
  }

  io.println("-- parsing source (" <> parameters.input_dir <> ")")

  use parsed: VXML <- infra.on_error_on_ok(
    over: renderer.source_parser(assembled),
    with_on_error: fn(error: c) {
      case debug_options.error_messages {
        True -> io.println("renderer.source_parser error: " <> ins(error))
        _ -> Nil
      }
      Error(SourceParserError(error))
    },
  )

  io.print("-- starting pipeline...")
  let t0 = timestamp.system_time()

  use desugared <- infra.on_error_on_ok(
    over: pipeline_runner(
      parsed,
      renderer.pipeline,
      debug_options.pipeline_debug_options,
      1,
    ),
    with_on_error: fn(e: InSituDesugaringError) {
      case debug_options.error_messages {
        True -> {
          {
            "\nError thrown by " <> e.desugarer.name <> ".gleam desugarer" <>
            "\nPipeline position: " <> ins(e.pipeline_step) <>
            "\nBlame: " <> ins(e.blame) <>
            "\nMessage: " <> e.message <>
            "\n"
          }
          |> io.print
        }
        False -> Nil
      }
      Error(PipelineError(e))
    },
  )

  let t1 = timestamp.system_time()
  let s = timestamp.difference(t0, t1) |> duration.to_seconds |> float.to_precision(2)
  io.println(" ...ended pipeline (" <> ins(s) <> "s)")

  // vxml fragments generation
  use fragments <- infra.on_error_on_ok(
    over: renderer.splitter(desugared),
    with_on_error: fn(error: e) {
      possible_error_message(debug_options, "splitter error: " <> ins(error))
      Error(SplitterError(error))
    },
  )

  // blamed line fragments .emu debug printing
  fragments
  |> list.each(fn(triple) {
    let #(local_path, vxml, fragment_type) = triple
    case
      debug_options.splitter_debug_options.debug_print(
        local_path,
        vxml,
        fragment_type,
      )
    {
      False -> Nil
      True -> {
        vxml
        |> vp.vxml_to_blamed_lines
        |> bl.blamed_lines_to_table_vanilla_bob_and_jane_sue(
          "("
            <> ins(list.length(renderer.pipeline))
            <> ":splitter_debug_options:"
            <> local_path
            <> ")",
          _,
        )
        |> io.println
      }
    }
  })

  io.println("-- converting vxml fragments to blamed line fragments")

  // vxml fragments -> blamed line fragments
  let fragments =
    fragments
    |> list.map(fn(tuple) {
      let #(name, _, _) = tuple
      renderer.emitter(tuple)
      |> quick_message("   converted: " <> name <> " to blamed lines")
    })

  io.println("-- blamed lines debug printing")

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
            bl.blamed_lines_to_table_vanilla_bob_and_jane_sue(
              "(emitter_debug_options:" <> local_path <> ")",
              blamed_lines,
            )
            |> io.println
          }
        }
      }
    }
  })

  io.println("-- converting blamed line fragments to strings")

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
          Ok(#(local_path, bl.blamed_lines_to_string(lines), fragment_type))
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

  io.println("-- writing string fragments to files")

  // printing string fragments (list.map to record errors)
  let fragments =
    fragments
    |> list.map(fn(result) {
      use triple <- result.try(result)
      let #(local_path, content, fragment_type) = triple
      use output_dir <- infra.on_none_on_some(
        parameters.output_dir,
        Ok(#(local_path, fragment_type)),
      )
      case output_dir_local_path_printer(output_dir, local_path, content) {
        Ok(Nil) -> {
          case debug_options.basic_messages {
            False -> Nil
            True -> io.println("   wrote: [" <> output_dir <> "/]" <> local_path)
          }
          Ok(#(local_path, fragment_type))
        }
        Error(file_error) ->
          Error(C2(
            { file_error |> ins }
            <> " on path "
            <> output_dir
            <> "/"
            <> local_path,
          ))
      }
    })

  // running prettifier (list.map to record erros)
  let fragments =
    fragments
    |> list.map(fn(result) {
      use #(local_path, fragment_type) <- result.try(result)
      use output_dir <- infra.on_none_on_some(parameters.output_dir, result)
      case renderer.prettifier(output_dir, #(local_path, fragment_type)) {
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

pub type CommandLineAmendments {
  CommandLineAmendments(
    input_dir: Option(String),
    output_dir: Option(String),
    debug_assembled_input: Bool,
    debug_pipeline_range: #(Int, Int),
    debug_pipeline_names: List(String),
    basic_messages: Bool,
    debug_vxml_fragments_local_paths: List(String),
    debug_blamed_lines_fragments_local_paths: List(String),
    debug_printed_string_fragments_local_paths: List(String),
    debug_prettified_string_fragments_local_paths: List(String),
    spotlight_args: List(#(String, String, String)),
    spotlight_args_files: List(String),
    user_args: Dict(String, List(String)),
  )
}

//********************
// BUILDING COMMAND LINE AMENDMENTS FROM COMMAND LINE ARGS
//********************

pub fn empty_command_line_amendments() -> CommandLineAmendments {
  CommandLineAmendments(
    input_dir: None,
    output_dir: None,
    debug_assembled_input: False,
    debug_pipeline_range: #(-1, -1),
    debug_pipeline_names: [],
    basic_messages: True,
    debug_vxml_fragments_local_paths: [],
    debug_blamed_lines_fragments_local_paths: [],
    debug_printed_string_fragments_local_paths: [],
    debug_prettified_string_fragments_local_paths: [],
    spotlight_args: [],
    spotlight_args_files: [],
    user_args: dict.from_list([]),
  )
}

fn amend_debug_assembled_input(
  amendments: CommandLineAmendments,
  val: Bool,
) -> CommandLineAmendments {
  CommandLineAmendments(..amendments, debug_assembled_input: val)
}

fn amend_debug_pipeline_range(
  amendments: CommandLineAmendments,
  start: Int,
  end: Int,
) -> CommandLineAmendments {
  CommandLineAmendments(..amendments, debug_pipeline_range: #(start, end))
}

fn amend_debug_pipeline_names(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_pipeline_names: list.append(
      amendments.debug_pipeline_names,
      names,
    ),
  )
}

pub fn amend_debug_vxml_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_vxml_fragments_local_paths: list.append(
      amendments.debug_vxml_fragments_local_paths,
      names,
    ),
  )
}

pub fn amend_debug_blamed_lines_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_blamed_lines_fragments_local_paths: list.append(
      amendments.debug_blamed_lines_fragments_local_paths,
      names,
    ),
  )
}

fn amend_debug_printed_string_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_printed_string_fragments_local_paths: list.append(
      amendments.debug_printed_string_fragments_local_paths,
      names,
    ),
  )
}

fn amend_debug_prettified_string_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_prettified_string_fragments_local_paths: list.append(
      amendments.debug_prettified_string_fragments_local_paths,
      names,
    ),
  )
}

fn amend_user_args(
  amendments: CommandLineAmendments,
  key: String,
  values: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    user_args: dict.insert(amendments.user_args, key, values),
  )
}

fn amend_spotlight_args(
  amendments: CommandLineAmendments,
  args: List(#(String, String, String)),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    spotlight_args: list.append(amendments.spotlight_args, args),
    spotlight_args_files: list.append(
      amendments.spotlight_args_files,
      args
        |> list.map(fn(a) {
          let #(path, _, _) = a
          path
        }),
    ),
  )
}

pub fn cli_usage() {
  io.println("command line options (mix & match any combination):")
  io.println("")
  io.println("      --spotlight <path1> <path2> ...")
  io.println("         -> spotlight the given paths before assembling")
  io.println("      --debug-assembled-input <name1> <name2> ...")
  io.println("         -> print assembled blamed lines before parsing")
  io.println("      --debug-pipeline <name1> <name2> ...")
  io.println("         -> print output of pipes with given names")
  io.println("      --debug-pipeline-<x>-<y>")
  io.println("         -> print output of pipes number x up to y")
  io.println("      --debug-pipeline-<x>")
  io.println("         -> print output of pipe number x")
  io.println("      --debug-pipeline-last")
  io.println("         -> print output of last pipe")
  io.println("      --debug-pipeline-0-0")
  io.println("         -> print output of all pipes")
  io.println("      --debug-fragments-emu <local_path1> <local_path2> ...")
  io.println(
    "         -> print blamed lines of fragments associated to local paths",
  )
  io.println("      --debug-fragments-bl <local_path1> <local_path2> ...")
  io.println("         -> print blamed lines of local paths")
  io.println("      --debug-fragments-printed <local_path1> <local_path2> ...")
  io.println("         -> print unprettified output files of local paths")
  io.println(
    "      --debug-fragments-prettified <local_path1> <local_path2> ...",
  )
  io.println("         -> print prettified output files of local paths")
}

pub type CommandLineError {
  ExpectedDoubleDashString(String)
  UnwantedOptionArgument(String)
  ErrorRunningSpotlight(Int, String)
  BadDebugPipelineRange(String)
}

fn parse_attribute_value_args_in_filename(
  path: String,
) -> List(#(String, String, String)) {
  let assert [path, ..args] = string.split(path, "&")
  case args {
    [] -> [#(path, "", "")]
    _ ->
      list.map(args, fn(arg) {
        let assert [key, value] = string.split(arg, "=")
        #(path, key, value)
      })
  }
}

pub fn process_command_line_arguments(
  arguments: List(String),
  xtra_keys: List(String),
) -> Result(CommandLineAmendments, CommandLineError) {
  use list_key_values <- infra.on_error_on_ok(
    double_dash_keys(arguments),
    fn(bad_key) { Error(ExpectedDoubleDashString(bad_key)) },
  )

  list_key_values
  |> list.fold(Ok(empty_command_line_amendments()), fn(result, pair) {
    use amendments <- result.try(result)
    let #(option, values) = pair
    case option {
      "--debug-assembled-input" -> {
        Ok(amendments |> amend_debug_assembled_input(True))
      }

      "--debug-assembled" -> {
        Ok(amendments |> amend_debug_assembled_input(True))
      }

      "--debug-fragments-emu" -> {
        Ok(amendments |> amend_debug_vxml_fragments_local_paths(values))
      }

      "--debug-fragments-bl" -> {
        Ok(amendments |> amend_debug_blamed_lines_fragments_local_paths(values))
      }

      "--debug-fragments-printed" -> {
        Ok(
          amendments |> amend_debug_printed_string_fragments_local_paths(values),
        )
      }

      "--debug-fragments-prettified" -> {
        Ok(
          amendments
          |> amend_debug_prettified_string_fragments_local_paths(values),
        )
      }

      "--spotlight" -> {
        let args =
          values
          |> list.map(parse_attribute_value_args_in_filename)
          |> list.flatten()
        Ok(amendments |> amend_spotlight_args(args))
      }

      "--debug-pipeline" -> {
        case list.is_empty(values) {
          True -> Ok(amendments |> amend_debug_pipeline_range(0, 0))
          False ->
            Ok(amendments |> amend_debug_pipeline_names(values))
        }
      }

      "--debug-pipeline-last" -> {
        case list.is_empty(values) {
          True -> Ok(amendments |> amend_debug_pipeline_range(-2, -2))
          False ->
            Ok(amendments |> amend_debug_pipeline_names(values))
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
                      amendments
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
                      amendments
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
            case list.contains(xtra_keys, option) {
              False -> Error(UnwantedOptionArgument(option))
              True -> Ok(amendments |> amend_user_args(option, values))
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
  amendments: CommandLineAmendments,
) -> String {
  case amendments.input_dir {
    None -> input_dir
    Some(other) -> other
  }
}

fn pr_amend_output_dir(
  output_dir: Option(String),
  amendments: CommandLineAmendments,
) -> Option(String) {
  case amendments.input_dir {
    None -> output_dir
    Some(other) -> Some(other)
  }
}

pub fn amend_renderer_paramaters_by_command_line_amendment(
  parameters: RendererParameters,
  amendments: CommandLineAmendments,
) -> RendererParameters {
  RendererParameters(
    pr_amend_input_dir(parameters.input_dir, amendments),
    pr_amend_output_dir(parameters.output_dir, amendments),
  )
}

//********************
// AMENDING RENDERER DEBUG OPTIONS BY COMMAND LINE AMENDMENTS
//********************

pub fn db_amend_assembler_debug_options(
  options: BlamedLinesAssemblerDebugOptions,
  amendments: CommandLineAmendments,
) -> BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    ..options,
    debug_print: amendments.debug_assembled_input,
  )
}

pub fn db_amend_pipeline_debug_options(
  options: PipelineDebugOptions,
  amendments: CommandLineAmendments,
  pipeline: List(Desugarer),
) -> PipelineDebugOptions {
  let PipelineDebugOptions(_, artifact_print, artifact_directory) = options

  let #(start, end) = amendments.debug_pipeline_range
  let names = amendments.debug_pipeline_names

  PipelineDebugOptions(
    fn(step, pipe) {
      { start == 0 && end == 0 }
      || { start <= step && step <= end }
      || { start == -2 && end == -2 && step == list.length(pipeline) }
      || {
        list.is_empty(names) == False
        && list.any(names, fn (name) { string.contains(pipe.name, name) })
      }
    },
    artifact_print,
    artifact_directory,
  )
}

pub fn db_amend_splitter_debug_options(
  options: SplitterDebugOptions(a),
  amendments: CommandLineAmendments,
) -> SplitterDebugOptions(a) {
  let SplitterDebugOptions(
    previous_condition,
    artifact_print,
    artifact_directory,
  ) = options

  SplitterDebugOptions(
    fn(local_path, vxml, fragment_type) {
      previous_condition(local_path, vxml, fragment_type)
      || list.any(
        amendments.debug_vxml_fragments_local_paths,
        string.contains(local_path, _),
      )
    },
    artifact_print,
    artifact_directory,
  )
}

pub fn db_amend_emitter_debug_options(
  options: EmitterDebugOptions(a),
  amendments: CommandLineAmendments,
) -> EmitterDebugOptions(a) {
  let EmitterDebugOptions(
    previous_condition,
    artifact_print,
    artifact_directory,
  ) = options

  EmitterDebugOptions(
    fn(local_path, lines, fragment_type) {
      previous_condition(local_path, lines, fragment_type)
      || list.any(
        amendments.debug_blamed_lines_fragments_local_paths,
        string.contains(local_path, _),
      )
    },
    artifact_print,
    artifact_directory,
  )
}

pub fn db_amend_printed_debug_options(
  options: PrinterDebugOptions(d),
  amendments: CommandLineAmendments,
) -> PrinterDebugOptions(d) {
  let PrinterDebugOptions(previous_condition) = options

  PrinterDebugOptions(fn(local_path, fragment_type) {
    {
      previous_condition(local_path, fragment_type)
      || list.any(
        amendments.debug_printed_string_fragments_local_paths,
        string.contains(local_path, _),
      )
    }
  })
}

pub fn db_amend_prettifier_debug_options(
  options: PrettifierDebugOptions(d),
  amendments: CommandLineAmendments,
) -> PrettifierDebugOptions(d) {
  let PrettifierDebugOptions(previous_condition) = options

  PrettifierDebugOptions(fn(local_path, fragment_type) {
    {
      previous_condition(local_path, fragment_type)
      || list.contains(
        amendments.debug_prettified_string_fragments_local_paths,
        local_path,
      )
    }
  })
}

pub fn amend_renderer_debug_options_by_command_line_amendment(
  debug_options: RendererDebugOptions(d),
  amendments: CommandLineAmendments,
  pipeline: List(Desugarer),
) -> RendererDebugOptions(d) {
  RendererDebugOptions(
    debug_options.basic_messages,
    debug_options.error_messages,
    db_amend_assembler_debug_options(
      debug_options.assembler_debug_options,
      amendments,
    ),
    debug_options.source_parser_debug_options,
    db_amend_pipeline_debug_options(
      debug_options.pipeline_debug_options,
      amendments,
      pipeline,
    ),
    db_amend_splitter_debug_options(
      debug_options.splitter_debug_options,
      amendments,
    ),
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

pub fn empty_prettifier_debug_options() -> PrettifierDebugOptions(d) {
  PrettifierDebugOptions(debug_print: fn(_local_path, _fragment_type) { False })
}

pub fn empty_renderer_debug_options(
  artifact_directory: String,
) -> RendererDebugOptions(d) {
  RendererDebugOptions(
    basic_messages: True,
    error_messages: True,
    assembler_debug_options: empty_assembler_debug_options(artifact_directory),
    source_parser_debug_options: empty_source_parser_debug_options(artifact_directory),
    pipeline_debug_options: empty_pipeline_debug_options(artifact_directory),
    splitter_debug_options: empty_splitter_debug_options(artifact_directory),
    emitter_debug_options: empty_emitter_debug_options(artifact_directory),
    printer_debug_options: empty_printer_debug_options(),
    prettifier_debug_options: empty_prettifier_debug_options(),
  )
}
