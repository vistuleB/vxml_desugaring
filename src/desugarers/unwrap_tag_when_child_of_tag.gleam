import gleam/list
import gleam/option
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, T, V}

fn transform(
  vxml: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  inner: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      let #(to_be_unwrapped, parent) = inner
      case to_be_unwrapped == tag {
        False -> Ok([vxml])
        True -> {
          case list.first(ancestors) {
            Error(Nil) -> Ok([vxml])
            Ok(first) -> {
              let assert V(_, first_tag, _, _) = first
              case first_tag == parent {
                False -> Ok([vxml])
                True -> Ok(children)
              }
            }
          }
        }
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

type Param = #(String, String)
//            ↖       ↖
//            to_be   parent
//            unwrapped

type InnerParam = Param

/// unwraps specified tag when it is a child of specified parent tag
pub fn unwrap_tag_when_child_of_tag(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: "unwrap_tag_when_child_of_tag",
      stringified_param: option.Some(ins(param)),
      general_description: "/// unwraps specified tag when it is a child of specified parent tag",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}