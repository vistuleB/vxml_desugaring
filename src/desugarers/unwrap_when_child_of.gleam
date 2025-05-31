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
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case vxml {
    T(_, _) -> Ok([vxml])
    V(_, tag, _, children) -> {
      case infra.use_list_pair_as_dict(param, tag) {
        Error(Nil) -> Ok([vxml])
        Ok(parent_tags) -> {
          case list.first(ancestors) {
            Error(Nil) -> Ok([vxml])
            Ok(parent) -> {
              let assert V(_, actual_parent_tag, _, _) = parent
              case list.contains(parent_tags, actual_parent_tag) {
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

type Param =
  List(#(String,     List(String)))
//        ↖            ↖
//         tag to be    list of parent tag names
//         unwrapped    that will cause child to unwrap

type InnerParam = Param

/// unwrap nodes based on parent-child
/// relationships
pub fn unwrap_when_child_of(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap_when_child_of", option.Some(ins(param)), "unwrap nodes based on parent-child
relationships"),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
