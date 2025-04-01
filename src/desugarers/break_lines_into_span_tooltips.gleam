import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, DesugaringError, Pipe } as infra
import vxml_parser.{ type BlamedContent, type VXML, BlamedAttribute, BlamedContent, T, V }

fn line_to_tooltip_span(bc: BlamedContent, prefix: Extra) -> VXML {
  let location =
    prefix <> bc.blame.filename <> ":" <> ins(bc.blame.line_no) <> ":" <> "50"
  V(
    bc.blame,
    "span",
    [BlamedAttribute(bc.blame, "class", "tooltip-3003-container")],
    [
      V(
        bc.blame,
        "span",
        [
          BlamedAttribute(bc.blame, "class", "tooltip-3003-text")
        ],
        [
          T(bc.blame, [BlamedContent(bc.blame, bc.content)])
        ],
      ),
      V(
        bc.blame,
        "span",
        [
          BlamedAttribute(bc.blame, "class", "tooltip-3003"),
          BlamedAttribute(bc.blame, "onClick", "sendCmdTo3003('code --goto " <> location <> "');"),
        ],
        [
          T(bc.blame, [BlamedContent(bc.blame, location)])
        ],
      ),
    ],
  )
}

fn param_transform(
  vxml: VXML,
  extra: Extra,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(blame, lines) -> {
      Ok([
        V(
          blame,
          "span",
          [],
          lines
            |> list.map(line_to_tooltip_span(_, extra))
            |> list.intersperse(
              T(blame, [BlamedContent(blame, ""), BlamedContent(blame, "")]),
            ),
        ),
      ])
    }
    _ -> Ok([vxml])
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
  param_transform(_, extra)
  |> infra.prevent_node_to_nodes_transform_inside(["Math", "MathBlock"])
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

type Extra =
  String

pub fn break_lines_into_span_tooltips(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "break_lines_into_span_tooltips",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
