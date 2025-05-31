import gleam/option
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, BlamedAttribute, T, V}

pub fn insert_indent_transform(
  node: VXML,
  ancestors: List(VXML),
  previous_unmapped_siblings: List(VXML),
  _: List(VXML),
  _: List(VXML),
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> Ok(node)
    V(blame, "VerticalChunk", attrs, children) -> {
      case previous_unmapped_siblings {
        [V(_, "VerticalChunk", _, _), ..] -> {
          case
            infra.contains_one_of_tags(ancestors, [
              "CentralDisplay", "CentralDisplayItalic",
            ])
          {
            True -> Ok(node)
            False ->
              Ok(V(
                blame,
                "VerticalChunk",
                [BlamedAttribute(blame, "indent", "true"), ..attrs],
                children,
              ))
          }
        }
        _ -> Ok(node)
      }
    }
    V(_, _, _, _) -> Ok(node)
  }
}

fn transform_factory(_param: InnerParam) -> infra.NodeToNodeFancyTransform {
  insert_indent_transform
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Nil

type InnerParam = Nil

/// Adds an 'indent true' attribute-value pair
/// to VerticalChunk nodes that directly follow
/// VerticalChunk nodes
pub fn insert_indent() -> Pipe {
  Pipe(
    description: DesugarerDescription("insert_indent", option.None, "
Adds an 'indent true' attribute-value pair
to VerticalChunk nodes that whose previous
sibling is also a VerticalChunk node
      ",
    ),
    desugarer: case param_to_inner_param(Nil) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
