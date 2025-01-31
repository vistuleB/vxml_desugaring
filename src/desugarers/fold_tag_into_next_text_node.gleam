import gleam/option.{None, type Option, Some}
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError,
} as infra
import vxml_parser.{type VXML, T, V,  BlamedContent, type BlamedContent}

fn append_to_next_text_node(fold_as: String, node: VXML) -> List(VXML) {
  case node {
    T(b, contents) -> {
      // JOHN: use infra.start_insert_text for this case
      case contents {
        [] -> [T(b, [BlamedContent(b, fold_as)])]
        [BlamedContent(blame, content), ..rest_contents] -> {
          [T(b, [BlamedContent(blame, fold_as <> content), ..rest_contents])]
        }
      }
    }
    V(b, _, _, _) as v -> {
      [T(b, [BlamedContent(b, fold_as)]), v]
    }
  }
}

fn param_transform(
  vxml: VXML,
  _: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  _: List(VXML),
  _: List(VXML),
  extra: Extra
  ) -> Result(List(VXML), DesugaringError) {
  let #(tag_to_fold, fold_as) = extra
  
  case vxml {
    V(_, tag, _, _) if tag == tag_to_fold -> Ok([])
    _ -> {
      case previous_siblings_before_mapping {
        [V(_, tag, _, _), ..] if tag == tag_to_fold -> {
          let vxmls = append_to_next_text_node(fold_as, vxml)
          Ok(vxmls)
        }
        _ -> Ok([vxml])
      }
    }
  }
}
 

type Extra =
  #(String, String)

fn transform_factory(extra: Extra) -> infra.NodeToNodesFancyTransform {
   fn(node, ancestors, s1, s2, s3) {
    param_transform(node, ancestors, s1, s2, s3, extra)
  }
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(extra))
}

pub fn fold_tag_into_next_text_node(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("fold_tag_into_next_text_node", None, "..."),
    desugarer_factory(extra),
  )
}
