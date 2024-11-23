import gleam/list
import gleam/option.{type Option}
import gleam/result
import vxml_parser.{type Blame, type VXML, T, V}

pub type DesugaringError {
  DesugaringError(blame: Blame, message: String)
}

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

pub type NodeToNodeTransform =
  fn(VXML) -> Result(VXML, DesugaringError)

fn depth_first_node_to_node_desugar_many(
  vxmls: List(VXML),
  transform: NodeToNodeTransform,
) {
  let mapper = depth_first_node_to_node_desugar_one(_, transform)
  map_result(vxmls, mapper)
}

fn depth_first_node_to_node_desugar_one(
  node: VXML,
  transform: NodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> transform(node)
    V(blame, tag, attrs, children) -> {
      case depth_first_node_to_node_desugar_many(children, transform) {
        Ok(transformed_children) ->
          transform(V(blame, tag, attrs, transformed_children))
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn depth_first_node_to_node_desugarer(
  root: VXML,
  transform: NodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  depth_first_node_to_node_desugar_one(root, transform)
}

pub fn depth_first_node_to_node_desugarer_many(
  vxmls: List(VXML),
  transform: NodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  depth_first_node_to_node_desugar_many(vxmls, transform)
}

//**********************************************************************
//* desugaring efforts #1.5: depth-first-search, node-to-node          *
//* transform with lots of side info (not only ancestors)              *
//**********************************************************************

pub type NodeToNodeFancyTransform =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(VXML, DesugaringError)

fn fancy_depth_first_node_to_node_children_traversal(
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodeFancyTransform,
) -> Result(#(List(VXML), List(VXML), List(VXML)), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, []),
      )
    [first, ..rest] -> {
      use first_replacement <- result.then(
        fancy_depth_first_node_to_node_desugar_one(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      fancy_depth_first_node_to_node_children_traversal(
        ancestors,
        [first, ..previous_siblings_before_mapping],
        [first_replacement, ..previous_siblings_after_mapping],
        rest,
        transform,
      )
    }
  }
}

fn fancy_depth_first_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodeFancyTransform,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) ->
      transform(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    V(blame, tag, attrs, children) -> {
      case
        fancy_depth_first_node_to_node_children_traversal(
          [node, ..ancestors],
          [],
          [],
          children,
          transform,
        )
      {
        Ok(#(_, mapped_children, _)) ->
          transform(
            V(blame, tag, attrs, mapped_children |> list.reverse),
            ancestors,
            previous_siblings_before_mapping,
            previous_siblings_after_mapping,
            following_siblings_before_mapping,
          )
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn fancy_depth_first_node_to_node_desugarer(
  root: VXML,
  transform: NodeToNodeFancyTransform,
) -> Result(VXML, DesugaringError) {
  fancy_depth_first_node_to_node_desugar_one(root, [], [], [], [], transform)
}

//**********************************************************************
//* desugaring efforts #2: depth-first-search, node-to-nodes transform *
//* ; see 'pub' function(s) below                                      *
//**********************************************************************

pub type NodeToNodesTransform =
  fn(VXML) -> Result(List(VXML), DesugaringError)

fn depth_first_node_to_nodes_desugar_many(
  vxmls: List(VXML),
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  let mapper = depth_first_node_to_nodes_desugar_one(_, transform)
  case map_result(vxmls, mapper) {
    Ok(replacement_lists) -> Ok(list.flatten(replacement_lists))
    Error(err) -> Error(err)
  }
}

fn depth_first_node_to_nodes_desugar_one(
  node: VXML,
  transform: NodeToNodesTransform,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> transform(node)
    V(blame, tag, attrs, children) -> {
      case depth_first_node_to_nodes_desugar_many(children, transform) {
        Ok(new_children) -> transform(V(blame, tag, attrs, new_children))
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn depth_first_node_to_nodes_desugarer(
  root: VXML,
  transform: NodeToNodesTransform,
) -> Result(VXML, DesugaringError) {
  case depth_first_node_to_nodes_desugar_one(root, transform) {
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
  depth_first_node_to_nodes_desugar_many(vxmls, transform)
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

//*****************
//* pipeline type *
//*****************

pub type Desugarer =
  fn(VXML) -> Result(VXML, DesugaringError)

pub type DesugarerDescription {
  DesugarerDescription(
    function_name: String,
    extra: Option(String),
    general_description: String,
  )
}

pub type Pipe =
  #(DesugarerDescription, Desugarer)
