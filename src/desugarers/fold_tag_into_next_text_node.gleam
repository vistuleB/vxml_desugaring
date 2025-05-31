import gleam/option.{Some}
import gleam/string
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedContent, T, V}

const ins = string.inspect

fn prepend_to_next_text_node(text: String, node: VXML) -> List(VXML) {
  case node {
    T(_, _) -> [infra.t_start_insert_text(node, text)]
    V(b, _, _, _) as v -> [T(b, [BlamedContent(b, text)]), v]
  }
}

fn transform(
  vxml: VXML,
  _: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  _: List(VXML),
  _: List(VXML),
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  let #(tag_to_fold, fold_as) = param

  case vxml {
    V(_, tag, _, _) if tag == tag_to_fold -> Ok([])
    _ -> {
      case previous_siblings_before_mapping {
        [V(_, tag, _, _), ..] if tag == tag_to_fold -> {
          let vxmls = prepend_to_next_text_node(fold_as, vxml)
          Ok(vxmls)
        }
        _ -> Ok([vxml])
      }
    }
  }
}

type Param =
  #(String, String)

type InnerParam = Param

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    transform(node, ancestors, s1, s2, s3, param)
  }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

pub fn fold_tag_into_next_text_node(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "fold_tag_into_next_text_node",
      Some(param |> ins),
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error)}
      Ok(param) -> desugarer_factory(param)
    }
  )
}
