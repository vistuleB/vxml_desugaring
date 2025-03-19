import gleam/option.{ Some }
import gleam/list
import gleam/io
import gleam/string
import gleam/result
import infrastructure.{type Pipe} as infra
import vxml_renderer as vr
import writerly_parser as wp
import blamedlines.{type BlamedLine, type Blame, BlamedLine, Blame}
import vxml_parser.{type VXML, V}
import desugarers/filter_nodes_by_attributes


const ins = string.inspect

type FragmentType = Nil
type SplitterError = Nil
type EmitterError = Nil

fn blame_us(message: String) -> Blame {
  Blame(message, -1, [])
}

pub fn default_source_parser(
  lines: List(BlamedLine),
  spotlight_args: List(#(String, String, String))
) -> Result(VXML, vr.RendererError(a, String, c, d, e)) {
  use writerlys <- result.then(
    wp.parse_blamed_lines(lines)
    |> result.map_error(fn(e) { vr.SourceParserError(ins(e)) })
  )

  use vxml <- result.then(
    wp.writerlys_to_vxmls(writerlys)
    |> infra.get_root
    |> result.map_error(vr.SourceParserError)
  )

  use filtered_vxml <- result.then(
    filter_nodes_by_attributes.filter_nodes_by_attributes(spotlight_args).desugarer(vxml)
    |> result.map_error(fn(e: infra.DesugaringError) { vr.SourceParserError(ins(e)) })
  )

  Ok(filtered_vxml)
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
    vr.process_command_line_arguments(arguments, ["--prettier"]),
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
    vr.RendererError(VXML, String, c, d, e),
    Nil,
    Nil,
    Nil,
    #(Int, String),
  ) = vr.Renderer(
    assembler: wp.assemble_blamed_lines_advanced_mode(_, amendments.spotlight_args_files),
    source_parser: default_source_parser(_, amendments.spotlight_args),
    pipeline: pipeline,
    splitter: default_splitter,
    emitter: default_emitter,
    prettifier: vr.guarded_prettier_prettifier(amendments.user_args),
  )

  let parameters = vr.RendererParameters(
    input_dir: "test/content/",
    output_dir: Some("test/output/"),
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
