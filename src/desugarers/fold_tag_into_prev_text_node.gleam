import gleam/list
import gleam/option.{None}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedContent, T, V}

fn append_to_prev_text_node(fold_as: String, node: VXML) -> List(VXML) {
  case node {
    T(b, contents) -> {
      case contents {
        [] -> [T(b, [BlamedContent(b, fold_as)])]
        [BlamedContent(blame, content), ..rest_contents] -> {
          [
            T(
              b,
              list.flatten([
                rest_contents,
                [BlamedContent(blame, content <> fold_as)],
              ]),
            ),
          ]
        }
      }
    }
    V(b, _, _, _) as v -> {
      [v, T(b, [BlamedContent(b, fold_as)])]
    }
  }
}

fn transform(
  vxml: VXML,
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  following_siblings_before_mapping: List(VXML),
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  let #(tag_to_fold, fold_as) = param

  case vxml {
    V(_, tag, _, _) if tag == tag_to_fold -> Ok([])
    _ -> {
      case following_siblings_before_mapping {
        [V(_, tag, _, _), ..] if tag == tag_to_fold -> {
          let vxmls = append_to_prev_text_node(fold_as, vxml)
          Ok(vxmls)
        }
        _ -> Ok([vxml])
      }
    }
  }
}


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

type Param = #(String, String)
type InnerParam = Param

pub fn fold_tag_into_prev_text_node(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "fold_tag_into_prev_text_node",
      None,
      "...",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
