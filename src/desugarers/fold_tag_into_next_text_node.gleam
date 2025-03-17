import gleam/option.{Some}
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, T, V,  BlamedContent, type BlamedContent}

const ins = string.inspect

fn prepend_to_next_text_node(text: String, node: VXML) -> List(VXML) {
  case node {
    T(_, _) -> [infra.t_start_insert_text(node, text)]
    V(b, _, _, _) as v -> [T(b, [BlamedContent(b, text)]), v]
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
          let vxmls = prepend_to_next_text_node(fold_as, vxml)
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
  Pipe(
    description: DesugarerDescription("fold_tag_into_next_text_node", Some(extra |> ins), "..."),
    desugarer: desugarer_factory(extra),
  )
}
