import gleam/list
import gleam/option
import gleam/pair
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  inner: InnerParam
) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, tag, atts, children) -> {
      case list.find(inner, fn(pair) { pair |> pair.first == tag }) {
        Error(Nil) -> Ok(vxml)
        Ok(#(_, #(start_tag, end_tag))) -> {
          Ok(V(
            blame,
            tag,
            atts,
            [
              [V(blame, start_tag, [], [])],
              children,
              [V(blame, end_tag, [], [])],
            ]
              |> list.flatten,
          ))
        }
      }
    }
    T(_, _) -> Ok(vxml)
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> infra.triples_to_pairs
  |> Ok
}

type Param =
  List(#(String, String, String))

type InnerParam =
  List(#(String, #(String, String)))

pub fn insert_bookend_tags(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "insert_bookend_tags",
      option.None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}
