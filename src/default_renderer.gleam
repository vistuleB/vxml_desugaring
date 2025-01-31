import gleam/option.{ Some }
import gleam/list
import gleam/io
import gleam/string
import infrastructure.{type Pipe} as infra
import vxml_renderer as vr
import writerly_parser as wp
import blamedlines.{type BlamedLine, type Blame, BlamedLine, Blame}
import vxml_parser.{type VXML, V}

const ins = string.inspect

type FragmentType = Nil
type SplitterError = Nil
type EmitterError = Nil

fn blame_us(message: String) -> Blame {
  Blame(message, -1, [])
}

pub fn default_splitter(root: VXML) -> Result(List(#(String, VXML, FragmentType)), SplitterError) {
  let assert V(_, tag, _, _) = root
  Ok(
    [
      #(tag <> ".tsx", root, Nil),
    ]
  )
}

fn default_emitter(
  triple : #(String, VXML, FragmentType),
) -> Result(#(String, List(BlamedLine), FragmentType), EmitterError) {
  let #(path, fragment, _) = triple

  let lines = list.flatten([
    [
      BlamedLine(blame_us("lbp_fragment_emitter"), 0, "const Article = () => {"),
      BlamedLine(blame_us("lbp_fragment_emitter"), 2, "return ("),
    ],
    vxml_parser.vxml_to_jsx_blamed_lines(fragment, 4),
    [
      BlamedLine(blame_us("lbp_fragment_emitter"), 2, ");"),
      BlamedLine(blame_us("lbp_fragment_emitter"), 0, "};"),
      BlamedLine(blame_us("lbp_fragment_emitter"), 0, ""),
      BlamedLine(blame_us("lbp_fragment_emitter"), 0, "export default Article;"),
    ]
  ])

  Ok(#(path, lines, Nil))
}

fn cli_usage_supplementary() {
  io.println("      --prettier")
  io.println("         -> run npm prettier on emitted content")
}

pub fn run_default_renderer(
  pipeline: List(Pipe),
  arguments: List(String),
) {
  use amendments <- infra.on_error_on_ok(
    vr.process_command_line_arguments(arguments, [#("--prettier", True)]),
    fn (error) {
      io.println("")
      io.println("command line error: " <> ins(error))
      io.println("")
      vr.cli_usage()
      cli_usage_supplementary()
    }
  )

  let renderer :
  vr.Renderer(
    wp.FileOrParseError,
    List(wp.Writerly),
    wp.WriterlyParseError,
    Nil,
    Nil,
    Nil,
    Bool,
    #(Int, String),
  ) = vr.Renderer(
    assembler: wp.assemble_blamed_lines_advanced_mode(_, amendments.assemble_blamed_lines_selector_args),
    source_parser: wp.parse_blamed_lines,
    parsed_source_converter: wp.writerlys_to_vxmls,
    pipeline: pipeline,
    splitter: default_splitter,
    emitter: default_emitter,
    prettifier: vr.prettier_prettifier,
  )

  let parameters = vr.RendererParameters(
    input_dir: "test/content/",
    output_dir: Some("test/output/"),
    prettifying_option: False,
  )
    |> vr.amend_renderer_paramaters_by_command_line_amendment(amendments)

  let debug_options = vr.empty_renderer_debug_options("../renderer_artifacts")
    |> vr.amend_renderer_debug_options_by_command_line_amendment(amendments, pipeline)

  case vr.run_renderer(
    renderer,
    parameters,
    debug_options,
  ) {
    Ok(Nil) -> Nil
    Error(error) -> io.println("\nrenderer error: " <> ins(error) <> "\n")
  }
}
