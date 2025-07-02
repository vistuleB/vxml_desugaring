import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
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
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  let #(tag_to_fold, fold_as) = inner

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

fn transform_factory(inner: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(node, ancestors, s1, s2, s3) {
    transform(node, ancestors, s1, s2, s3, inner)
  }
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, String)
//  ↖       ↖
//  tag     fold
//  to      as
//  fold    text

type InnerParam = Param

/// folds specified tags into the previous text node
/// as text content
pub fn fold_tag_into_prev_text_node(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "fold_tag_into_prev_text_node",
      stringified_param: option.Some(ins(param)),
      general_description: "
/// folds specified tags into the previous text node
/// as text content
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}