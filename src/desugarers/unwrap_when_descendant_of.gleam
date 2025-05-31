import gleam/list
import gleam/option.{Some}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type VXML, V}

fn transform(
  node: VXML,
  ancestors: List(VXML),
  _: List(VXML),
  _: List(VXML),
  _: List(VXML),
  param: InnerParam,
) -> Result(List(VXML), DesugaringError) {
  case node {
    V(_, tag, _, children) ->
      case infra.use_list_pair_as_dict(param, tag) {
        Error(Nil) -> Ok([node])
        Ok(forbidden) -> {
          let ancestor_names = list.map(ancestors, infra.get_tag)
          case list.any(ancestor_names, list.contains(forbidden, _)) {
            True -> Ok(children)
            False -> Ok([node])
          }
        }
      }
    _ -> Ok([node])
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodesFancyTransform {
  fn(vxml: VXML, s1: List(VXML), s2: List(VXML), s3: List(VXML), s4: List(VXML)) {
    transform(vxml, s1, s2, s3, s4, param)
  }
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_nodes_fancy_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  List(#(String,    List(String)))
//        ↖            ↖
//         tag to be    list of ancestor names
//         unwrapped    that will cause tag to unwrap

type InnerParam = Param

pub fn unwrap_when_descendant_of(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription("unwrap_when_descendant_of", Some(ins(param)), "unwraps tags that are the descendant of
one of a stipulated list of tag names"),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
