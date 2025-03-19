import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type Pipe, DesugarerDescription, Pipe} as infra
import vxml_parser.{type VXML, T, V}

fn param_transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  extra: Extra,
) -> Result(VXML, infra.DesugaringError) {
  case vxml {
    V(_, _, _, _) -> Ok(vxml)
    T(_, _) -> {
      list.fold(extra, vxml, fn(v, tuple) -> VXML {
        let #(ancestor, list_pairs) = tuple
        case list.any(ancestors, fn(a) { infra.get_tag(a) == ancestor }) {
          False -> v
          True -> infra.find_replace_in_t(vxml, list_pairs)
        }
      })
      |> Ok
    }
  }
}

fn transform_factory(extra: Extra) -> infra.NodeToNodeFancyTransform {
  fn(vxml, ancestors, s1, s2, s3) {
    param_transform(vxml, ancestors, s1, s2, s3, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(extra))
}

type Extra =
  List(
    #(String, List(#(String, String))),
    //    ancestor       from    to
  )

pub fn find_replace_in_descendants_of(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "find_replace_in_descendants_of",
      Some(ins(extra)),
      "...",
    ),
    desugarer: desugarer_factory(extra),
  )
}
