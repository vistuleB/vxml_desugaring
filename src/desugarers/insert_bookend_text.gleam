import gleam/list
import gleam/option
import gleam/pair
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(vxml: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    V(_, tag, _, _) -> {
      case list.find(param, fn(pair) { pair |> pair.first == tag }) {
        Error(Nil) -> Ok(vxml)
        Ok(#(_, #(start_text, end_text))) -> {
          vxml
          |> infra.v_start_insert_text(start_text)
          |> infra.v_end_insert_text(end_text)
          |> Ok
        }
      }
    }
    T(_, _) -> Ok(vxml)
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  param
  |> infra.triples_to_pairs
  |> Ok
}

type InnerParam =
  List(#(String, #(String, String)))

type Param =
  List(#(String, String, String))

pub fn insert_bookend_text(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("insert_bookend_text", option.None, "..."),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
