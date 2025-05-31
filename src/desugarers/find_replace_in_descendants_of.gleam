import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  param: InnerParam,
) -> Result(VXML, infra.DesugaringError) {
  case vxml {
    V(_, _, _, _) -> Ok(vxml)
    T(_, _) -> {
      list.fold(param, vxml, fn(v, tuple) -> VXML {
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

fn transform_factory(param: InnerParam) -> infra.NodeToNodeFancyTransform {
  fn(vxml, ancestors, s1, s2, s3) {
    transform(vxml, ancestors, s1, s2, s3, param)
  }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

//                 ancestor       from    to
type Param =List(#(String, List(#(String, String))))
type InnerParam = Param

pub fn find_replace_in_descendants_of(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "find_replace_in_descendants_of",
      Some(ins(param)),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
