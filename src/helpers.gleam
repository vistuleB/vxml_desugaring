import vxml_parser.{type VXML, T, V, type Blame}
import gleam/list

pub type DesugaringError {
  DesugaringError(blame: Blame, message: String)
}

pub type NodeToNodeTransform(extra) =
  fn(VXML, List(VXML), extra) -> Result(VXML, DesugaringError)

fn map_result(
  inputs: List(a),
  mapper: fn(a) -> Result(b, c),
) -> Result(List(b), c) {
  case inputs {
    [] -> Ok([])
    [first, ..rest] -> {
      case mapper(first) {
        Ok(output) -> {
          case map_result(rest, mapper) {
            Ok(results) -> Ok([output, ..results])
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn first_blame(vxml: VXML) -> Blame {
  case vxml {
    T(blame, _) -> blame
    V(blame, _, _, _) -> blame
  }
}

//**************************************************************
//* desugaring efforts #1 deliverable: 'pub' function(s) below *
//**************************************************************

fn depth_first_node_to_node_desugar_many(
  vxmls: List(VXML),
  ancestors: List(VXML),
  transform: NodeToNodeTransform(extra),
  extra: extra
) {
  let mapper = depth_first_node_to_node_desugar_one(_, ancestors, transform, extra)
  map_result(vxmls, mapper)
}

fn depth_first_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  transform: NodeToNodeTransform(extra),
  extra: extra
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> transform(node, ancestors, extra)
    V(blame, tag, attrs, children) -> {
      case
        depth_first_node_to_node_desugar_many(
          children,
          [node, ..ancestors],
          transform,
          extra
        )
      {
        Ok(transformed_children) ->
          transform(V(blame, tag, attrs, transformed_children), ancestors, extra)
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn depth_first_node_to_node_desugarer(
  root: VXML,
  transform: NodeToNodeTransform(extra),
  extra: extra
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugar_one(root, [], transform, extra)
}

pub fn depth_first_node_to_node_desugarer_many(
  vxmls: List(VXML),
  transform: NodeToNodeTransform(extra),
  extra: extra
) -> Result(List(VXML), DesugaringError) {
  depth_first_node_to_node_desugar_many(vxmls, [], transform, extra)
}

//**********************************************************************
//* desugaring efforts #2: depth-first-search, node-to-nodes transform *
//* ; see 'pub' function(s) below                                      *
//**********************************************************************

pub type NodeToNodesTransform =
  fn(VXML, List(VXML)) -> Result(List(VXML), DesugaringError)

fn depth_first_node_to_nodes_desugar_many(
  vxmls: List(VXML),
  ancestors: List(VXML),
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  let mapper = depth_first_node_to_nodes_desugar_one(_, ancestors, transform)
  case map_result(vxmls, mapper) {
    Ok(replacement_lists) -> Ok(list.concat(replacement_lists))
    Error(err) -> Error(err)
  }
}

fn depth_first_node_to_nodes_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> transform(node, ancestors)
    V(blame, tag, attrs, children) -> {
      case
        depth_first_node_to_nodes_desugar_many(
          children,
          [node, ..ancestors],
          transform,
        )
      {
        Ok(new_children) ->
          transform(V(blame, tag, attrs, new_children), ancestors)
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn depth_first_node_to_nodes_desugarer(
  root: VXML,
  transform: NodeToNodesTransform,
) -> Result(VXML, DesugaringError) {
  case depth_first_node_to_nodes_desugar_one(root, [], transform) {
    Ok([]) ->
      Error(DesugaringError(
        first_blame(root),
        "depth_first_node_to_nodes_desugarer received empty replacement for root",
      ))

    Ok([first]) -> Ok(first)

    Ok([_, ..]) ->
      Error(DesugaringError(
        first_blame(root),
        "depth_first_node_to_nodes_desugarer received list length > 1 replacement for root",
      ))

    Error(err) -> Error(err)
  }
}

pub fn depth_first_node_to_nodes_desugarer_many(
  vxmls: List(VXML),
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  depth_first_node_to_nodes_desugar_many(vxmls, [], transform)
}

//**************************************************************
//* desugaring efforts #3: breadth-first-search, node-to-node2 *
//* ; see 'pub' function below                                 *
//**************************************************************

pub type EarlyReturn(a) {
  DoNotRecurse(a)
  Recurse(a)
  Err(DesugaringError)
}

pub type EarlyReturnNodeToNodeTransform =
  fn(VXML, List(VXML)) -> EarlyReturn(VXML)

fn early_return_node_to_node_desugar_many(
  vxmls: List(VXML),
  ancestors: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  let mapper = early_return_node_to_node_desugar_one(_, ancestors, transform)
  map_result(vxmls, mapper)
}

fn early_return_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  case transform(node, ancestors) {
    DoNotRecurse(new_node) -> Ok(new_node)
    Recurse(new_node) -> {
      case new_node {
        T(_, _) -> Ok(new_node)
        V(blame, tag, attrs, children) -> {
          case
            early_return_node_to_node_desugar_many(
              children,
              [new_node, ..ancestors],
              transform,
            )
          {
            Ok(new_children) -> Ok(V(blame, tag, attrs, new_children))
            Error(err) -> Error(err)
          }
        }
      }
    }
    Err(error) -> Error(error)
  }
}

pub fn early_return_node_to_node_desugarer(
  root: VXML,
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  early_return_node_to_node_desugar_one(root, [], transform)
}

pub fn early_return_node_to_node_desugarer_many(
  vxmls: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  early_return_node_to_node_desugar_many(vxmls, [], transform)
}
