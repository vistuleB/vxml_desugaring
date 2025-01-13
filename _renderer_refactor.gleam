// *************
// BLAMED LINES ASSEMBLER(a)                 // a is error type of assembler
// file/directory -> List(BlamedLine)
// *************

type BlamedLinesAssembler(a) = 
  fn(input_dir: String) -> Result(List(BlamedLine), a)
  
type BlamedLinesAssemblerDebugOptions =
  BlamedLinesAssemblerDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    debug_print_blamed_lines: Bool,
    artifact_print_blamed_lines: String,
    artifact_print_is_debug_print: Bool,
  )

// *************
// SOURCE PARSER(b, c)                      // b is data type of parsed source (Writerly), c is error type of parser
// List(BlamedLines) -> parsed source
// *************

type SourceParser(b, c) = fn(List(BlamedLine)) -> Result(b, c)

type SourceParserDebugOptions =
  BlamedLinesAssemblerDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    debug_print_parsed_source: Bool,
    artifact_print_parse_source: String,
    artifact_print_is_debug_print: Bool
  )

// *************
// SOURCE_TO_VXML_CONVERTER(b)
// b -> VXML
// *************

type SourceToVXMLConverter(b) = fn(b) -> List(VXML)

type SourceToVXMLConverterDebugOptions =
  BlamedLinesAssemblerDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    debug_print: Bool,
    artifact_print: Bool,
    artifact_directory: String,
    artifact_print_is_debug_print: Bool
  )

// *************
// PIPELINE
// VXML -> ... -> VXML
// *************

type Pipeline = List(Pipe)

type PipelineDebugOptions = {
  DesugaringPipelineDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    debug_print: fn(Int, Pipe) -> Bool,
    artifact_print: fn(Int, Pipe) -> Bool,
    artifact_directory: String,
    artifact_print_is_debug_print: Bool,
  )
}

// *************
// SPLITTER(d, e)             // 'd' is fragment type, 'e' is error type for splitting
// VXML -> List(#(VXML, d)) 
// *************
  
type Splitter(d, e) = fn(VXML) -> Result(List(#(VXML, d)), e)

type SplitterDebugOptions = {
  SplitterDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    debug_print: fn(#(VXML, d)) -> Bool,
    artifact_print: fn(#(VXML, d)) -> Bool,
    artifact_directory: String,
    artifact_print_is_debug_print: Bool,
  )
}

// *************
// FRAGMENT EMITTER(d, f)                     // where 'd' is fragment type & 'e' is emitter error type
// #(VXML, d) -> #(String, List(BlamedLine))  // where 'String' is the filepath (f.g., 'chapters/Chapter1.tsx')
// *************

type FragmentEmitter(d, f) = fn(#(VXML, d)) -> Result(#(String, List(BlamedLine)), f)

type FragmentEmitterDebugOptions = {
  FragmentEmitterDebugOptions(
    basic_messages: Bool,
    debug_printing: Bool,
    debug_print: fn(#(VXML, d)) -> Bool,
    artifact_print: fn(#(VXML, d)) -> Bool,
    artifact_directory: String,
    artifact_print_is_debug_print: Bool,
  )
}

// *************
// FRAGMENT PRINTER(g)                 // where 'g' is printing error type (might include prettier error not only simplifile error)
// #(String, List(BlamedLine)) -> Nil
// *************

type FragmentPrinter(g) = fn(Option(String), #(String, List(BlamedBline))) -> Result(Nil, g)

type FragmentPrinterDebugOptions = {
  FragmentPrinterDebugOptions(
    basic_messages: Bool,
    error_messages: Bool,
    debug_print: fn(#(VXML, d)) -> Bool,
    artifact_print: fn(#(VXML, d)) -> Bool,
    artifact_directory: String,
    artifact_print_is_debug_print: Bool,
  )
}

// *************
// RENDERER(a, b, c, d, e, f, g) -- ALL TOGETHER
// file/directory -> file(s)
// *************

type Renderer(
  a, // error type for blamed line assembly
  b, // parsed source type (== Writerly)
  c, // blamed lines -> parsed source parsing error (== WriterlyParseError)
  d, // enum type for VXML Fragment
  e, // splitting error
  f, // fragment emitting error
  g, // fragment printing error
) = {
  Renderer(
    assembler: BlamedLinesAssembler(a),
    source_parser: SourceParser(b, c),
    source_converter: SourceToVXMLConverter(b),
    pipeline: List(Pipe),
    splitter: Splitter(d, e),                // VXML -> List(VXML)
    fragment_emitter: FragmentEmitter(d, f), // VXML -> List(BlamedLine)
    fragment_printer: FragmentPrinter(g),    // List(BlamedLine) & "just prints".... maybe runs prettier!
  )
}

type RendererError(a, c, e, f, g) = {
  AssemblyError(a)
  SourceParserError(c)
  GetRootError(String)
  SplitterError(e)
  EmittingOrPrintingErrors(List(EitherOr(f, g)))
  ArtifactPrintingError(String)
}

type RendererDebugOptions = {
  RendererDebugOptions(
    assembler_debug_options: BlamedLinesAssemblerDebugOptions,
    source_parser_debug_options: SourceParserDebugOptions,
    source_emitter_debug_options: SourceToVXMLConverterDebugOptions,
    pipeline_debug_options: PipelineDebugOptions,
    splitter_debug_options: SplitterDebugOptions,
    emitter_debug_options: EmitterDebugOptions,
  )
}

pub fn run_renderer(
  input_dir: String,
  renderer: Renderer(a, b, c, d, e, f, g),
  debug_options: RendererDebugOptions,
  output_dir: String,
) -> Result(Nil, RendererError(a, c, e, f, g)) {
  //** work starts here **//
}
