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
import gleam/time/timestamp.{type Timestamp}

// *************
// SOURCE ASSEMBLER(a)                             // 'a' is assembler error type
// file/directory -> List(BlamedLine)
// *************

pub type BlamedLinesAssembler(a) =
  fn(String) -> Result(List(BlamedLine), a)

pub type BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    debug_print: Bool,
  )
}

pub fn default_blamed_lines_assembler(
  spotlight_paths: List(String)
) -> BlamedLinesAssembler(wp.AssemblyError) {
  wp.assemble_blamed_lines_advanced_mode(_, spotlight_paths)
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
  )
}

// ******************************
// default source parsers
// ******************************

pub fn default_writerly_source_parser(
  spotlight_args: List(#(String, String, String)),
) -> SourceParser(String) {
  fn (lines) {
    use writerlys <- result.try(
      wp.parse_blamed_lines(lines)
      |> result.map_error(fn(e) { ins(e) }),
    )

    use vxml <- result.try(
      wp.writerlys_to_vxmls(writerlys)
      |> infra.get_root
    )

    use filtered_vxml <- result.try(
      filter_nodes_by_attributes(spotlight_args).transform(vxml)
      |> result.map_error(fn(e) { ins(e) }),
    )

    Ok(filtered_vxml)
  }
}

pub fn default_html_source_parser(
  spotlight_args: List(#(String, String, String)),
) -> SourceParser(String) {
  fn (lines) {
    let path = bl.filename_of_first_blame(lines) |> result.unwrap("")
    let s = string.trim(bl.blamed_lines_to_string(lines))
    use nonempty_string <- result.try(
      case s {
        "" -> Error("empty content")
        _ -> Ok(s)
      }
    )
    use vxml <- result.try(
      nonempty_string
      |> vp.xmlm_based_html_parser(path)
      |> result.map_error(fn(e) { ins(e) })
    )
    filter_nodes_by_attributes(spotlight_args).transform(vxml)
    |> result.map_error(fn(e) { ins(e) })
  }
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
  )
}

// *************
// OutputFragment(d, z)                         // 'd' is fragment classifier type, 'z' is payload type
// *************

pub type OutputFragment(d, z) {
  OutputFragment(
    path: String,
    payload: z,
    classifier: d,
  )
}

pub type GhostOfOutputFragment(d) {
  GhostOfOutputFragment(
    path: String,
    classifier: d,
  )
}

// *************
// SPLITTER(d, e)                                // 'd' is fragment classifier type, 'e' is splitter error type
// VXML -> List(OutputFragment)                  // #(local_path, vxml, fragment_type)
// *************

pub type Splitter(d, e) =
  fn(VXML) -> Result(List(OutputFragment(d, VXML)), e)

pub type SplitterDebugOptions(d) {
  SplitterDebugOptions(
    debug_print: fn(OutputFragment(d, VXML)) -> Bool,
  )
}

// ************************
// stub splitter
// ************************

/// emits 1 fragment whose 'path' is the tag
/// of the VXML root concatenated with a provided
/// suffix, e.g., "<> Book" -> "Book.html"
pub fn stub_splitter(
  suffix: String,
) -> Splitter(Nil, Nil) {
  fn (root) {
    let assert V(_, tag, _, _) = root
    Ok([OutputFragment(
      path: tag <> suffix,
      payload: root,
      classifier: Nil,
    )])
  }
}

// *************
// EMITTER(d, f)                                        // where 'd' is fragment type & 'f' is emitter error type
// OutputFragment(d) -> #(String, List(BlamedLine), d)  // #(local_path, blamed_lines, fragment_type)
// *************

pub type Emitter(d, f) =
  fn(OutputFragment(d, VXML)) -> Result(OutputFragment(d, List(BlamedLine)), f)

pub type EmitterDebugOptions(d) {
  EmitterDebugOptions(
    debug_print: fn(OutputFragment(d, List(BlamedLine))) -> Bool,
  )
}

// *****************
// stub writerly emitter
// *****************

pub fn stub_writerly_emitter(
  fragment: OutputFragment(d, VXML),
) -> Result(OutputFragment(d, List(BlamedLine)), b) {
  let lines =
    fragment.payload
    |> wp.vxml_to_writerlys
    |> wp.writerlys_to_blamed_lines
  Ok(OutputFragment(..fragment, payload: lines))
}

// *****************
// stub html emitter
// *****************

pub fn stub_html_emitter(
  fragment: OutputFragment(d, VXML),
) -> Result(OutputFragment(d, List(BlamedLine)), b) {
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
      fragment.payload
      |> infra.get_children
      |> list.map(fn(vxml) { vp.vxml_to_html_blamed_lines(vxml, 2, 2) })
      |> list.flatten,
      [
        BlamedLine(blame_us("stub_html_emitter"), 0, "</body>"),
        BlamedLine(blame_us("stub_html_emitter"), 0, ""),
      ],
    ])
  Ok(OutputFragment(..fragment, payload: lines))
}

pub fn stub_jsx_emitter(
  fragment: OutputFragment(d, VXML),
) -> Result(OutputFragment(d, List(BlamedLine)), b) {
  let blame_us = fn(msg: String) -> Blame { Blame(msg, 0, 0,[]) }
  let lines =
    list.flatten([
      [
        BlamedLine(blame_us("panel_emitter"), 0, "import Something from \"./Somewhere\";"),
        BlamedLine(blame_us("panel_emitter"), 0, ""),
        BlamedLine(blame_us("panel_emitter"), 0, "const OurSuperComponent = () => {"),
        BlamedLine(blame_us("panel_emitter"), 2, "return ("),
        BlamedLine(blame_us("panel_emitter"), 4, "<>"),
      ],
      vp.vxmls_to_jsx_blamed_lines(fragment.payload |> infra.get_children, 6),
      [
        BlamedLine(blame_us("panel_emitter"), 4, "</>"),
        BlamedLine(blame_us("panel_emitter"), 2, ");"),
        BlamedLine(blame_us("panel_emitter"), 0, "};"),
        BlamedLine(blame_us("panel_emitter"), 0, ""),
        BlamedLine(blame_us("panel_emitter"), 0, "export default OurSuperComponent;"),
      ],
    ])
  Ok(OutputFragment(..fragment, payload: lines))
}

// *************
// PRINTER
// (no function, only a DebugOption for printing
// what was printed to file before prettifying)
// *************

pub type PrinterDebugOptions(d) {
  PrinterDebugOptions(debug_print: fn(OutputFragment(d, String)) -> Bool)
}

// *************
// PRETTIFIER(d, h)                                          // where 'd' is fragment classifier, 'h' is prettifier error type
// String, GhostOfOutputFragment(d) -> Result(String, h)     // output_dir, ghost_of_output_fragment
// *************

pub type Prettifier(d, h) =
  fn(String, GhostOfOutputFragment(d)) -> Result(String, h)

pub type PrettifierDebugOptions(d) {
  PrettifierDebugOptions(debug_print: fn(GhostOfOutputFragment(d)) -> Bool)
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

pub fn default_prettier_prettifier(
  output_dir: String,
  ghost: GhostOfOutputFragment(d),
) -> Result(String, #(Int, String)) {
  run_prettier(".", output_dir <> "/" <> ghost.path)
  |> result.map(fn(_) { "prettified [" <> output_dir <> "/]" <> ghost.path })
}

pub fn empty_prettifier(_: String, _: #(String, d)) -> Result(String, Nil) {
  Ok("")
}

// *************
// RENDERER(a, b, c, d, e, f, g, h)
// *************

pub type Renderer(
  a, // BlamedLinesAssembler error type
  c, // SourceParser error type
  d, // VXML Fragment enum type
  e, // Splitter error type
  f, // Emitter error type
  h, // Prettifier error type
) {
  Renderer(
    assembler: BlamedLinesAssembler(a),     // file/directory -> List(BlamedLine)                     Result w/ error type a
    source_parser: SourceParser(c),         // List(BlamedLine) -> VXML                               Result w/ error type c
    pipeline: List(Desugarer),              // VXML -> ... -> VXML                                    Result w/ error type DesugaringError
    splitter: Splitter(d, e),               // VXML -> List(#(String, VXML, d))                       Result w/ error type e
    emitter: Emitter(d, f),                 // #(String, VXML, d) -> #(String, List(BlamedLine), d)   Result w/ error type f
    prettifier: Prettifier(d, h),           // String, #(String, d) -> Nil                            Result w/ error type h
  )
}

// *************
// RENDERER DEBUG OPTIONS(d)
// *************

pub type RendererDebugOptions(d) {
  RendererDebugOptions(
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
  RendererParameters(
    input_dir: String,
    output_dir: String,
    prettifier_on_by_default: Bool,
  )
}

// *************
// RENDERER IN-HOUSE HELPER FUNCTIONS
// *************

fn execute_pipeline(
  vxml: VXML,
  desugarers: List(Desugarer),
  pipeline_debug_options: PipelineDebugOptions,
) -> Result(#(VXML, List(#(Int, Timestamp))), InSituDesugaringError) {
  desugarers
  |> list.try_fold(
    #(vxml, 1, []),
    fn(acc, desugarer) {
      let #(vxml, step, times) = acc
      case pipeline_debug_options.debug_print(step, desugarer) {
        False -> Nil
        True ->
          star_block.desugarer_description_star_block(
            desugarer,
            step,
          )
          |> io.print
      }

      case desugarer.transform(vxml) {
        Ok(vxml) -> {
          let times = case desugarer.name == "timer" {
            True -> [#(step, timestamp.system_time()), ..times]
            False -> times
          }
          case pipeline_debug_options.debug_print(step, desugarer) {
            False -> Nil
            True -> vp.debug_print_vxml("(" <> ins(step) <> ")", vxml)
          }
          Ok(#(vxml, step + 1, times))
        }

        Error(error) -> Error(InSituDesugaringError(
          desugarer: desugarer,
          pipeline_step: step,
          blame: error.blame,
          message: error.message,
        ))
      }
    }
  )
  |> result.map(fn(acc){#(acc.0, acc.2)})
}

pub fn sanitize_output_dir(
  parameters: RendererParameters
) -> RendererParameters {
  RendererParameters(
    ..parameters,
    output_dir: infra.drop_ending_slash(parameters.output_dir)
  )
}

fn create_intermediate_dirs(output_dir: String, local_path: String) {
  let pieces = local_path |> string.split("/")
  let pieces = infra.drop_last(pieces)
  list.fold(
    pieces,
    output_dir,
    fn(acc, piece) {
      let acc = acc <> "/" <> piece
      case simplifile.is_directory(acc) {
        Ok(_) -> {
          let _ = simplifile.create_directory(acc)
          Nil
        }
        Error(_) -> Nil
      }
      acc
    }
  )
}

pub fn output_dir_local_path_printer(
  output_dir: String,
  local_path: String,
  content: String,
) -> Result(Nil, simplifile.FileError) {
  let assert False = string.starts_with(local_path, "/")
  let assert False = string.ends_with(output_dir, "/")
  create_intermediate_dirs(output_dir, local_path)
  let path = output_dir <> "/" <> local_path
  simplifile.write(path, content)
}

// *************
// RENDERER ERROR(a, c, e, f, h)
// *************

pub type RendererError(a, c, e, f, h) {
  FileOrParseError(a)
  SourceParserError(c)
  PipelineError(InSituDesugaringError)
  SplitterError(e)
  EmittingOrPrintingOrPrettifyingErrors(List(ThreePossibilities(f, String, h)))
}

pub type ThreePossibilities(f, g, h) {
  C1(f)
  C2(g)
  C3(h)
}

fn ddd_truncate(str: String, max_cols) -> String {
  case string.length(str) > max_cols {
    False -> str
    True -> {
      let excess = string.length(str) - max_cols
      string.drop_end(str, excess + 3) <> "..."
    }
  }
}

fn desugarer_to_list_lines(
  desugarer: Desugarer,
  index: Int,
  max_param_cols: Int,
  max_outside_cols: Int,
  none_string: String,
) -> List(#(String, String, String, String)) {
  let number = ins(index + 1) <> "."
  let name = desugarer.name
  let param_lines = case desugarer.stringified_param {
    None -> [none_string]
    Some(thing) -> case string.split(thing, "\n") {
      [] -> panic as "stringified param is empty string?"
      lines -> lines |> list.map(ddd_truncate(_, max_param_cols))
    }
  }
  let outside = case desugarer.stringified_outside {
    None -> none_string
    Some(thing) -> thing |> ddd_truncate(max_outside_cols)
  }
  list.index_map(
    param_lines,
    fn (p, i) {
      case i == 0 {
        True -> #(number, name, p, outside)
        False -> #("", star_block.spaces(string.length(name)), p, "⋮")
        // False -> #("", "", p, "⋮")
      }
    }
  )
}

fn print_pipeline(desugarers: List(Desugarer)) {
  let none_string = "--"
  let max_param_cols = 65
  let max_outside_cols = 45

  let lines =
    desugarers
    |> list.index_map(
      fn(d, i) {
        desugarer_to_list_lines(d, i, max_param_cols, max_outside_cols, none_string)
      }
    )
    |> list.flatten

  io.println("• desugarers in pipeline:")

  star_block.four_column_table(
    [
      #("#.", "name", "param", "outside"),
      ..lines,
    ],
    2,
  )
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
  let RendererParameters(input_dir, output_dir, prettifier) = parameters

  print_pipeline(renderer.pipeline)

  io.println("• assembling blamed lines (" <> input_dir <> ")")

  use assembled <- infra.on_error_on_ok(
    renderer.assembler(input_dir),
    fn(error_a) {
      io.println(
        "renderer.assembler error on input_dir "
        <> input_dir
        <> ": "
        <> ins(error_a),
      )
      Error(FileOrParseError(error_a))
    },
  )

  case debug_options.assembler_debug_options.debug_print {
    False -> Nil
    True ->
      assembled
      |> bl.blamed_lines_pretty_printer_no1("assembled")
      |> io.println
  }

  io.println("• parsing source (" <> input_dir <> ")")

  use parsed: VXML <- infra.on_error_on_ok(
    over: renderer.source_parser(assembled),
    with_on_error: fn(error: c) {
      io.println("renderer.source_parser error: " <> ins(error))
      Error(SourceParserError(error))
    },
  )

  io.print("• starting pipeline...")
  let t0 = timestamp.system_time()

  use #(desugared, times) <- infra.on_error_on_ok(
    over: execute_pipeline(
      parsed,
      renderer.pipeline,
      debug_options.pipeline_debug_options,
    ),
    with_on_error: fn(e: InSituDesugaringError) {
      let z = [
        "🏯🏯error thrown by: " <> e.desugarer.name <> ".gleam desugarer",
        "🏯🏯pipeline step:   " <> ins(e.pipeline_step),
        "🏯🏯blame:           " <> e.blame.filename <> ":" <> ins(e.blame.line_no) <> ":" <> ins(e.blame.char_no) <> " " <> ins(e.blame.comments),
        "🏯🏯message:         " <> e.message,
      ]
      let lengths = list.map(z, string.length)
      let width = list.fold(lengths, 0, fn (acc, n) { int.max(acc, n) }) + 2
      io.println("")
      io.println("")
      io.println(string.repeat("🏯", width * 6 / 11))
      io.println(string.repeat("🏯", width * 6 / 11))
      list.each(
        list.zip(z, lengths),
        fn(pair) { io.println(pair.0 <> star_block.spaces(width - pair.1 - 2) <> "🏯🏯") }
      )
      io.println(string.repeat("🏯", width * 6 / 11))
      io.println(string.repeat("🏯", width * 6 / 11))
      io.println("")
      Error(PipelineError(e))
    },
  )

  let t1 = timestamp.system_time()
  let seconds = timestamp.difference(t0, t1) |> duration.to_seconds |> float.to_precision(2)

  io.println(" ...ended pipeline (" <> ins(seconds) <> "s)")

  case list.length(times) > 0 {
    False -> Nil
    True -> {
      let times = [#(list.length(renderer.pipeline), t1), ..times]
      list.fold(
        times |> list.reverse,
        #(0, t0),
        fn (acc, next) {
          let #(step0, t0) = acc
          let #(step1, t1) = next
          let seconds = timestamp.difference(t0, t1) |> duration.to_seconds |> float.to_precision(3)
          io.println("  steps " <> ins(step0) <> " to " <> ins(step1) <> ": " <> ins(seconds) <> "s")
          next
        }
      )
      Nil
    }
  }

  io.print("• splitting the vxml...")

  // vxml fragments generation
  use fragments <- infra.on_error_on_ok(
    over: renderer.splitter(desugared),
    with_on_error: fn(error: e) {
      io.println("splitter error: " <> ins(error))
      Error(SplitterError(error))
    },
  )

  let prefix = "[" <> output_dir <> "/]"
  let fragments_types_and_paths_4_table = list.map(
    fragments,
    fn(fr) { #(ins(fr.classifier), prefix <> fr.path) }
  )

  io.println(" ...obtained " <> ins(list.length(fragments)) <> " fragments:")
  star_block.two_column_table(fragments_types_and_paths_4_table, "type", "path", 2)

  // fragments debug printing
  fragments
  |> list.each(fn(fr) {
    case debug_options.splitter_debug_options.debug_print(fr)
    {
      False -> Nil
      True -> {
        fr.payload
        |> vp.vxml_to_blamed_lines
        |> bl.blamed_lines_pretty_printer_no1("fr:" <> fr.path)
        |> io.println
      }
    }
  })

  io.println("• converting fragments to blamed line fragments")

  // vxml fragments -> blamed line fragments
  let fragments =
    fragments
    |> list.map(renderer.emitter)

  // blamed line fragments debug printing
  fragments
  |> list.each(fn(result) {
    case result {
      Error(_) -> Nil
      Ok(fr) -> {
        case debug_options.emitter_debug_options.debug_print(fr)
        {
          False -> Nil
          True -> {
            fr.payload
            |> bl.blamed_lines_pretty_printer_no1("fr-bl:" <> fr.path)
            |> io.println
          }
        }
      }
    }
  })

  io.println("• converting blamed line fragments to string fragments")

  // blamed line fragments -> string fragments
  let fragments = {
    fragments
    |> list.map(fn(result) {
      case result {
        Error(error) -> {
          io.println("emitting error: " <> ins(error))
          Error(C1(error))
        }
        Ok(fr) -> {
          Ok(OutputFragment(..fr, payload: bl.blamed_lines_to_string(fr.payload)))
        }
      }
    })
  }

  // string fragments debug printing
  fragments
  |> list.each(fn(result) {
    case result {
      Error(_) -> Nil
      Ok(fr) -> {
        case debug_options.printer_debug_options.debug_print(fr)
        {
          False -> Nil
          True -> {
            let header = "----------------- printer_debug_options: " <> fr.path <> " -----------------"
            io.println(header)
            io.println(fr.payload)
            io.println(star_block.dashes(string.length(header)))
            io.println("")
          }
        }
      }
    }
  })

  io.println("• writing string fragments to files")

  // printing string fragments (list.map to record errors)
  let fragments =
    fragments
    |> list.map(fn(result) {
      use fr <- result.try(result)
      let brackets = "[" <> output_dir <> "/]"
      case output_dir_local_path_printer(output_dir, fr.path, fr.payload) {
        Ok(Nil) -> {
          io.println("  wrote: " <> brackets <> fr.path)
          Ok(GhostOfOutputFragment(fr.path, fr.classifier))
        }
        Error(file_error) ->
          Error(C2(
            { file_error |> ins }
            <> " on path "
            <> output_dir
            <> "/"
            <> fr.path,
          ))
      }
    })

  // running prettifier (list.map to record erros)
  case prettifier {
    True -> io.println("• prettifying")
    False -> Nil
  }
  let fragments =
    fragments
    |> list.map(fn(result) {
      use <- infra.on_false_on_true(prettifier, result)
      use fr <- result.try(result)
      case renderer.prettifier(output_dir, fr) {
        Error(e) -> Error(C3(e))
        Ok(message) -> {
          case message != "" {
            True -> io.println("  " <> message)
            False -> Nil
          }
          result
        }
      }
    })

  // prettified fragments debug printing
  fragments
  |> list.each(fn(result) {
    use fr <- infra.on_error_on_ok(result, fn(_) { Nil })
    case debug_options.prettifier_debug_options.debug_print(fr)
    {
      False -> Nil
      True -> {
        let path = output_dir <> "/" <> fr.path
        use file_contents <- infra.on_error_on_ok(
          simplifile.read(path),
          fn(error) {
            io.println("")
            io.println("could not read back printed file " <> path <> ":" <> ins(error))
          },
        )
        io.println("")
        let header = "----------------- printer_debug_options: " <> fr.path <> " -----------------"
        io.println(header)
        io.println(file_contents)
        io.println(star_block.dashes(string.length(header)))
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
    help: Bool,
    input_dir: Option(String),
    output_dir: Option(String),
    debug_assembled_input: Bool,
    debug_pipeline_range: #(Int, Int),
    debug_pipeline_names: Option(List(String)),
    basic_messages: Bool,
    debug_vxml_fragments_local_paths: Option(List(String)),
    debug_blamed_lines_fragments_local_paths: Option(List(String)),
    debug_printed_string_fragments_local_paths: Option(List(String)),
    debug_prettified_string_fragments_local_paths: Option(List(String)),
    spotlight_key_values: List(#(String, String, String)),
    spotlight_paths: List(String),
    prettier: Option(Bool),
    user_args: Dict(String, List(String)),
  )
}

//********************
// BUILDING COMMAND LINE AMENDMENTS FROM COMMAND LINE ARGS
//********************

pub fn empty_command_line_amendments() -> CommandLineAmendments {
  CommandLineAmendments(
    help: False,
    input_dir: None,
    output_dir: None,
    debug_assembled_input: False,
    debug_pipeline_range: #(-1, -1),
    debug_pipeline_names: None,
    basic_messages: True,
    debug_vxml_fragments_local_paths: None,
    debug_blamed_lines_fragments_local_paths: None,
    debug_printed_string_fragments_local_paths: None,
    debug_prettified_string_fragments_local_paths: None,
    spotlight_key_values: [],
    spotlight_paths: [],
    prettier: None,
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
    debug_pipeline_names: Some(names),
  )
}

pub fn amend_debug_vxml_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_vxml_fragments_local_paths: Some(names),
  )
}

pub fn amend_debug_blamed_lines_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_blamed_lines_fragments_local_paths: Some(names),
  )
}

fn amend_debug_printed_string_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_printed_string_fragments_local_paths: Some(names),
  )
}

fn amend_debug_prettified_string_fragments_local_paths(
  amendments: CommandLineAmendments,
  names: List(String),
) -> CommandLineAmendments {
  CommandLineAmendments(
    ..amendments,
    debug_prettified_string_fragments_local_paths: Some(names),
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
    spotlight_key_values: list.append(amendments.spotlight_key_values, args),
    spotlight_paths: list.append(
      amendments.spotlight_paths,
      args
        |> list.map(fn(a) {
          let #(path, _, _) = a
          path
        }),
    ),
  )
}

pub fn cli_usage() {
  let margin = "   "
  io.println("")
  // io.println("You can mix and match the following command line options:")
  io.println("Renderer options:")
  io.println("")
  io.println(margin <> "--help")
  io.println(margin <> "  -> print this message")
  io.println("")
  io.println(margin <> "--spotlight <subpath1> <subpath2> ...")
  io.println(margin <> "  -> restrict source to paths that match one of the given subpaths")
  io.println("")
  io.println(margin <> "--spotlight <key1=val1> <key2=val2> ...")
  io.println(margin <> "  -> restrict source to elements that have one of the")
  io.println(margin <> "  given key-value pairs as attributes")
  io.println("")
  io.println(margin <> "--prettier0")
  io.println(margin <> "  -> turn the prettifier off if on by default")
  io.println("")
  io.println(margin <> "--prettier1")
  io.println(margin <> "  -> turn the prettifier on if off by default")
  io.println("")
  io.println(margin <> "--debug-assembled-input | --debug-assembled")
  io.println(margin <> "  -> print assembled blamed lines before parsing")
  io.println("")
  io.println(margin <> "--debug-pipeline <name1> <name2> ...")
  io.println(margin <> "  -> print output of desugarers with given names, list no names")
  io.println(margin <> "  to match all")
  io.println("")
  io.println(margin <> "--debug-pipeline-<x>-<y>")
  io.println(margin <> "  -> print output of desugarers number x up to y")
  io.println("")
  io.println(margin <> "--debug-pipeline-<x>")
  io.println(margin <> "  -> print output of desugarer number x")
  io.println("")
  io.println(margin <> "--debug-pipeline-last")
  io.println(margin <> "  -> print last output of pipeline")
  io.println("")
  io.println(margin <> "--debug-pipeline-")
  io.println(margin <> "  -> an ignored option that useful to keep '--debug-pipeline-'")
  io.println(margin <> "  -> close at hand on the command line")
  io.println("")
  io.println(margin <> "--debug-fragments <subpath1> <subpath2> ...")
  io.println(margin <> "  -> print fragments whose paths contain one of the given subpaths")
  io.println(margin <> "  before conversion blamed lines, list no subpaths to match all")
  io.println("")
  io.println(margin <> "--debug-fragments-bl <subpath1> <subpath2> ...")
  io.println(margin <> "  -> print fragments whose paths contain one of the given subpaths")
  io.println(margin <> "  after conversion blamed lines, list no subpaths to match all")
  io.println("")
  io.println(margin <> "--debug-fragments-printed <subpath1> <subpath2> ...")
  io.println(margin <> "  -> print fragments whose paths contain one of the given subpaths")
  io.println(margin <> "  in string form before prettifying, list no subpaths to match all")
  io.println("")
  io.println(margin <> "--debug-fragments-prettified <local_path1> <local_path2> ...")
  io.println(margin <> "  -> print fragments whose paths contain one of the given subpaths")
  io.println(margin <> "  in string form after prettifying, list no subpaths to match all")
}

pub type CommandLineError {
  ExpectedDoubleDashString(String)
  UnwantedOptionArgument(String)
  ErrorRunningSpotlight(Int, String)
  BadDebugPipelineRange(String)
  UnexpectedArgumentsToOption(String)
}

fn parse_attribute_value_args_in_filename(
  path: String,
) -> List(#(String, String, String)) {
  let assert [path, ..args] = string.split(path, "&")
  case args {
    [] -> {
      case string.split_once(path, "=") {
        Ok(#(key, value)) -> [#("", key, value)]
        Error(Nil) -> [#(path, "", "")]
      }
    }
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
      "--help" -> {
        cli_usage()
        io.println("")
        case list.is_empty(values) {
          True -> Ok(CommandLineAmendments(..amendments, help: True))
          False -> Error(UnexpectedArgumentsToOption("option"))
        }
      }

      "--prettier0" ->
        case list.is_empty(values) {
          True -> Ok(CommandLineAmendments(..amendments, prettier: Some(False)))
          False -> Error(UnexpectedArgumentsToOption("--prettier0"))
        }

      "--prettier1" ->
        case list.is_empty(values) {
          True -> Ok(CommandLineAmendments(..amendments, prettier: Some(True)))
          False -> Error(UnexpectedArgumentsToOption("--prettier1"))
        }

      "--debug-assembled-input" | "--debug-assembled" ->
        case list.is_empty(values) {
          True -> Ok(amendments |> amend_debug_assembled_input(True))
          False -> Error(UnexpectedArgumentsToOption(option))
        }

      "--debug-fragments" ->
        Ok(amendments |> amend_debug_vxml_fragments_local_paths(values))

      "--debug-fragments-bl" ->
        Ok(amendments |> amend_debug_blamed_lines_fragments_local_paths(values))

      "--debug-fragments-printed" ->
        Ok(amendments |> amend_debug_printed_string_fragments_local_paths(values))

      "--debug-fragments-prettified" ->
        Ok(amendments |> amend_debug_prettified_string_fragments_local_paths(values))

      "--spotlight" -> {
        let args =
          values
          |> list.map(parse_attribute_value_args_in_filename)
          |> list.flatten()
        Ok(amendments |> amend_spotlight_args(args))
      }

      "--debug-pipeline" ->
        case list.is_empty(values) {
          True -> Ok(amendments |> amend_debug_pipeline_range(0, 0))
          False ->
            Ok(amendments |> amend_debug_pipeline_names(values))
        }

      "--debug-pipeline-last" ->
        case list.is_empty(values) {
          True -> Ok(amendments |> amend_debug_pipeline_range(-2, -2))
          False ->
            Ok(amendments |> amend_debug_pipeline_names(values))
        }

      _ -> {
        case string.starts_with(option, "--debug-pipeline-") {
          True -> {
            let suffix = string.drop_start(option, string.length("--debug-pipeline-"))
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
                  _ -> case suffix {
                    "" -> Ok(amendments)
                    _ -> Error(BadDebugPipelineRange(option))
                  }
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

fn override_if_some(thing: a, replacement: Option(a)) -> a {
  case replacement {
    None -> thing
    Some(replacement) -> replacement
  }
}

pub fn amend_renderer_paramaters_by_command_line_amendment(
  parameters: RendererParameters,
  amendments: CommandLineAmendments,
) -> RendererParameters {
  RendererParameters(
    input_dir: override_if_some(parameters.input_dir, amendments.input_dir),
    output_dir: override_if_some(parameters.output_dir, amendments.input_dir),
    prettifier_on_by_default: override_if_some(parameters.prettifier_on_by_default, amendments.prettier),
  )
}

//********************
// AMENDING RENDERER DEBUG OPTIONS BY COMMAND LINE AMENDMENTS
//********************

fn is_some_and_contains_or_is_empty(z: Option(List(a)), thing: a) -> Bool {
  case z {
    None -> False
    Some([]) -> True
    Some(x) -> list.contains(x, thing)
  }
}

fn is_some_and_any_or_is_empty(z: Option(List(a)), f: fn(a) -> Bool) -> Bool {
  case z {
    None -> False
    Some([]) -> True
    Some(x) -> list.any(x, f)
  }
}

pub fn db_amend_assembler_debug_options(
  _options: BlamedLinesAssemblerDebugOptions,
  amendments: CommandLineAmendments,
) -> BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    debug_print: amendments.debug_assembled_input,
  )
}

pub fn db_amend_pipeline_debug_options(
  _previous: PipelineDebugOptions,
  amendments: CommandLineAmendments,
  pipeline: List(Desugarer),
) -> PipelineDebugOptions {
  let #(start, end) = amendments.debug_pipeline_range
  let names = amendments.debug_pipeline_names
  PipelineDebugOptions(
    debug_print: fn(step, desugarer: Desugarer) {
      { start == 0 && end == 0 }
      || { start <= step && step <= end }
      || { start == -2 && end == -2 && step == list.length(pipeline) }
      || { is_some_and_contains_or_is_empty(names, desugarer.name) }
    },
  )
}

pub fn db_amend_splitter_debug_options(
  previous: SplitterDebugOptions(d),
  amendments: CommandLineAmendments,
) -> SplitterDebugOptions(d) {
  SplitterDebugOptions(
    debug_print: fn(fr: OutputFragment(d, VXML)) {
      previous.debug_print(fr) || is_some_and_any_or_is_empty(
        amendments.debug_vxml_fragments_local_paths,
        string.contains(fr.path, _),
      )
    },
  )
}

pub fn db_amend_emitter_debug_options(
  previous: EmitterDebugOptions(d),
  amendments: CommandLineAmendments,
) -> EmitterDebugOptions(d) {
  EmitterDebugOptions(
    debug_print: fn(fr: OutputFragment(d, List(BlamedLine))) {
      previous.debug_print(fr) || is_some_and_any_or_is_empty(
        amendments.debug_blamed_lines_fragments_local_paths,
        string.contains(fr.path, _),
      )
    },
  )
}

pub fn db_amend_printed_debug_options(
  previous: PrinterDebugOptions(d),
  amendments: CommandLineAmendments,
) -> PrinterDebugOptions(d) {
  PrinterDebugOptions(
    fn(fr: OutputFragment(d, String)) {
      previous.debug_print(fr) || is_some_and_any_or_is_empty(
        amendments.debug_printed_string_fragments_local_paths,
        string.contains(fr.path, _),
      )
    }
  )
}

pub fn db_amend_prettifier_debug_options(
  previous: PrettifierDebugOptions(d),
  amendments: CommandLineAmendments,
) -> PrettifierDebugOptions(d) {
  PrettifierDebugOptions(
    fn(fr: GhostOfOutputFragment(d)) {
      previous.debug_print(fr) || is_some_and_any_or_is_empty(
        amendments.debug_prettified_string_fragments_local_paths,
        string.contains(fr.path, _),
      )
    }
  )
}

pub fn amend_renderer_debug_options_by_command_line_amendment(
  debug_options: RendererDebugOptions(d),
  amendments: CommandLineAmendments,
  pipeline: List(Desugarer),
) -> RendererDebugOptions(d) {
  RendererDebugOptions(
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
) -> BlamedLinesAssemblerDebugOptions {
  BlamedLinesAssemblerDebugOptions(
    debug_print: False,
  )
}

pub fn empty_source_parser_debug_options(
) -> SourceParserDebugOptions {
  SourceParserDebugOptions(
    debug_print: False,
  )
}

pub fn empty_pipeline_debug_options(
) -> PipelineDebugOptions {
  PipelineDebugOptions(
    debug_print: fn(_step, _pipe) { False },
  )
}

pub fn empty_splitter_debug_options(
) -> SplitterDebugOptions(d) {
  SplitterDebugOptions(
    debug_print: fn(_fr) { False },
  )
}

pub fn empty_emitter_debug_options(
) -> EmitterDebugOptions(d) {
  EmitterDebugOptions(
    debug_print: fn(_fr) { False },
  )
}

pub fn empty_printer_debug_options() -> PrinterDebugOptions(d) {
  PrinterDebugOptions(
    debug_print: fn(_fr) { False }
  )
}

pub fn empty_prettifier_debug_options() -> PrettifierDebugOptions(d) {
  PrettifierDebugOptions(
    debug_print: fn(_fr) { False }
  )
}

pub fn default_renderer_debug_options(
) -> RendererDebugOptions(d) {
  RendererDebugOptions(
    assembler_debug_options: empty_assembler_debug_options(),
    source_parser_debug_options: empty_source_parser_debug_options(),
    pipeline_debug_options: empty_pipeline_debug_options(),
    splitter_debug_options: empty_splitter_debug_options(),
    emitter_debug_options: empty_emitter_debug_options(),
    printer_debug_options: empty_printer_debug_options(),
    prettifier_debug_options: empty_prettifier_debug_options(),
  )
}
