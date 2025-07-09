import gleam/result
import gleam/list
import vxml.{type VXML, V, T}
import infrastructure.{type DesugarerTransform, type DesugaringError, DesugaringError} as infra
import blamedlines

//**************************************************************
//* desugaring efforts #1 deliverable: 'pub' function(s) below *
//**************************************************************

pub type NodeToNodeTransform =
  fn(VXML) -> Result(VXML, DesugaringError)

fn node_to_node_desugar_many(
  vxmls: List(VXML),
  transform: NodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  vxmls
  |> list.map(node_to_node_desugar_one(_, transform))
  |> result.all
}

fn node_to_node_desugar_one(
  node: VXML,
  transform: NodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> transform(node)
    V(blame, tag, attrs, children) -> {
      case node_to_node_desugar_many(children, transform) {
        Ok(transformed_children) ->
          transform(V(blame, tag, attrs, transformed_children))
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn node_to_node_desugarer_factory(
  transform: NodeToNodeTransform,
) -> DesugarerTransform {
  node_to_node_desugar_one(_, transform)
}

// fn one_to_one_nodemap_recursive_application(
//   node: VXML,
//   nodemap: OneToOneNodeMap,
// ) -> Result(VXML, DesugaringError) {
//   case node {
//     T(_, _) -> nodemap(node)
//     V(_, _, _, children) -> {
//       use children <- result.try(
//         children
//         |> list.map(one_to_one_nodemap_recursive_application(_, nodemap))
//         |> result.all
//       )
//       nodemap(V(..node, children: children))
//     }
//   }
// }

// pub type DesugarerTransform =
//   fn(VXML) -> Result(VXML, DesugaringError)

// pub fn one_to_one_nodemap_2_transform(
//   nodemap: OneToOneNodeMap,
// ) -> DesugarerTransform {
//   one_to_one_nodemap_recursive_application(_, nodemap)
// }

//**********************************************************************
//* desugaring efforts #1.5: depth-first-search, node-to-node          *
//* transform with lots of side info (not only ancestors)              *
//**********************************************************************

pub type NodeToNodeFancyTransform =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(VXML, DesugaringError)

fn fancy_node_to_node_children_traversal(
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
      use first_replacement <- result.try(
        fancy_node_to_node_desugar_one(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      fancy_node_to_node_children_traversal(
        ancestors,
        [first, ..previous_siblings_before_mapping],
        [first_replacement, ..previous_siblings_after_mapping],
        rest,
        transform,
      )
    }
  }
}

fn fancy_node_to_node_desugar_one(
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
      use #(_, reversed_children, _) <- result.try(
        fancy_node_to_node_children_traversal(
          [node, ..ancestors],
          [],
          [],
          children,
          transform,
      ))

      transform(
        V(blame, tag, attrs, reversed_children |> list.reverse),
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    }
  }
}

pub fn node_to_node_fancy_desugarer_factory(
  transform: NodeToNodeFancyTransform,
) -> DesugarerTransform {
  fancy_node_to_node_desugar_one(_, [], [], [], [], transform)
}

//**********************************************************************
//* desugaring efforts #1.6: depth-first-search, node-to-nodes         *
//* transform with lots of side info (not only ancestors)              *
//**********************************************************************

pub type NodeToNodesFancyTransform =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(List(VXML), DesugaringError)

fn fancy_node_to_nodes_children_traversal(
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodesFancyTransform,
) -> Result(#(List(VXML), List(VXML), List(VXML)), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, []),
      )
    [first, ..rest] -> {
      use first_replacement <- result.try(
        fancy_node_to_nodes_desugar_one(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      fancy_node_to_nodes_children_traversal(
        ancestors,
        [first, ..previous_siblings_before_mapping],
        list.flatten([
          first_replacement |> list.reverse,
          previous_siblings_after_mapping,
        ]),
        rest,
        transform,
      )
    }
  }
}

fn fancy_node_to_nodes_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: NodeToNodesFancyTransform,
) -> Result(List(VXML), DesugaringError) {
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
        fancy_node_to_nodes_children_traversal(
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

pub fn node_to_nodes_fancy_desugarer_factory(
  transform: NodeToNodesFancyTransform,
) -> DesugarerTransform {
  fn(root: VXML) {
    use vxmls <- result.try(fancy_node_to_nodes_desugar_one(
      root,
      [],
      [],
      [],
      [],
      transform,
    ))

    case infra.get_root(vxmls) {
      Ok(r) -> Ok(r)
      Error(message) -> Error(DesugaringError(blamedlines.empty_blame(), message))
    }
  }
}

//**********************************************************************
//* desugaring efforts #1.7: turn ordinary node-to-node(s) transform   *
//* into parent-avoiding fancy transform                               *
//**********************************************************************

pub fn prevent_node_to_node_transform_inside(
  transform: NodeToNodeTransform,
  forbidden_tag: List(String),
) -> NodeToNodeFancyTransform {
  fn(
    node: VXML,
    ancestors: List(VXML),
    _: List(VXML),
    _: List(VXML),
    _: List(VXML),
  ) -> Result(VXML, DesugaringError) {
    let node_is_forbidden_tag = case node {
      T(_, _) -> False
      V(_, tag, _, _) -> list.contains(forbidden_tag, tag)
    }
    case
      node_is_forbidden_tag
      || list.any(ancestors, fn(ancestor) {
        list.contains(forbidden_tag, infra.get_tag(ancestor))
      })
    {
      False -> transform(node)
      True -> Ok(node)
    }
  }
}

pub fn prevent_node_to_nodes_transform_inside(
  transform: NodeToNodesTransform,
  neutralize_here: List(String),
) -> NodeToNodesFancyTransform {
  fn(
    node: VXML,
    ancestors: List(VXML),
    _: List(VXML),
    _: List(VXML),
    _: List(VXML),
  ) -> Result(List(VXML), DesugaringError) {
    case
      list.any(ancestors, fn(ancestor) {
        list.contains(neutralize_here, infra.get_tag(ancestor))
      })
    {
      False -> transform(node)
      True -> Ok([node])
    }
  }
}

//**************************************************************
//* desugaring efforts #1.8: stateful node-to-node
//**************************************************************

pub type StatefulNodeToNodeTransform(a) =
  fn(VXML, a) -> Result(#(VXML, a), DesugaringError)

fn stateful_node_to_node_desugar_one(
  state: a,
  node: VXML,
  transform: StatefulNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> transform(node, state)
    V(blame, tag, attrs, children) -> {
      use #(transformed_children, new_state) <- result.try(
        infra.try_map_fold(children, state, fn(x, y) { stateful_node_to_node_desugar_one(x, y, transform) })
      )
      transform(V(blame, tag, attrs, transformed_children), new_state)
    }
  }
}

pub fn stateful_node_to_node_desugarer_factory(
  transform: StatefulNodeToNodeTransform(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    case stateful_node_to_node_desugar_one(initial_state, vxml, transform) {
      Error(err) -> Error(err)
      Ok(#(new_vxml, _)) -> Ok(new_vxml)
    }
  }
}

//**********************************************************************
//* desugaring efforts #1.85: stateful node-to-node with fancy
//* transform (NOT CURRENTLY USED == NOT CURRENTLY TESTED)
//**********************************************************************

pub type StatefulNodeToNodeFancyTransform(a) =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
    Result(#(VXML, a), DesugaringError)

fn stateful_fancy_depth_first_node_to_node_children_traversal(
  state: a,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: StatefulNodeToNodeFancyTransform(a),
) -> Result(#(List(VXML), List(VXML), List(VXML), a), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, [], state),
      )
    [first, ..rest] -> {
      use #(first_replacement, state) <- result.try(
        stateful_fancy_depth_first_node_to_node_desugar_one(
          state,
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      stateful_fancy_depth_first_node_to_node_children_traversal(
        state,
        ancestors,
        [first, ..previous_siblings_before_mapping],
        [first_replacement, ..previous_siblings_after_mapping],
        rest,
        transform,
      )
    }
  }
}

fn stateful_fancy_depth_first_node_to_node_desugar_one(
  state: a,
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: StatefulNodeToNodeFancyTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) ->
      transform(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
        state,
      )
    V(blame, tag, attrs, children) -> {
      case
        stateful_fancy_depth_first_node_to_node_children_traversal(
          state,
          [node, ..ancestors],
          [],
          [],
          children,
          transform,
        )
      {
        Ok(#(_, mapped_children, _, state)) ->
          transform(
            V(blame, tag, attrs, mapped_children |> list.reverse),
            ancestors,
            previous_siblings_before_mapping,
            previous_siblings_after_mapping,
            following_siblings_before_mapping,
            state,
          )

        Error(err) -> Error(err)
      }
    }
  }
}

pub fn stateful_node_to_node_fancy_desugarer_factory(
  transform: StatefulNodeToNodeFancyTransform(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    case stateful_fancy_depth_first_node_to_node_desugar_one(initial_state, vxml, [], [], [], [], transform) {
      Error(err) -> Error(err)
      Ok(#(vxml, _)) -> Ok(vxml)
    }
  }
}

//**********************************************************************
//* desugaring efforts #1.9: stateful down-up node-to-node
//**********************************************************************

pub type StatefulDownAndUpNodeToNodeTransform(a) {
  StatefulDownAndUpNodeToNodeTransform(
    v_before_transforming_children: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
    v_after_transforming_children: fn(VXML, a, a) ->
      Result(#(VXML, a), DesugaringError),
    t_transform: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
  )
}

fn stateful_down_up_node_to_node_one(
  original_state: a,
  node: VXML,
  transform: StatefulDownAndUpNodeToNodeTransform(a),
) -> Result(#(VXML, a), DesugaringError) {

  case node {
    V(_, _, _, children) -> {
      use #(node, state) <- result.try(
        transform.v_before_transforming_children(
          node,
          original_state,
        ),
      )

      use #(children, state) <- result.try(
        infra.try_map_fold(
          children,
          state,
          fn (x, y) { stateful_down_up_node_to_node_one(x, y, transform) }
        )
      )

      transform.v_after_transforming_children(
        node |> infra.replace_children_with(children),
        original_state,
        state,
      )
    }
    T(_, _) -> transform.t_transform(node, original_state)
  }
}

pub fn stateful_down_up_node_to_node_desugarer_factory(
  transform: StatefulDownAndUpNodeToNodeTransform(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    use #(vxml, _) <- result.try(stateful_down_up_node_to_node_one(
      initial_state,
      vxml,
      transform
    ))
    Ok(vxml)
  }
}

//**********************************************************************
//* desugaring efforts #1.91: stateful down-up node-to-node
//**********************************************************************

pub type StatefulDownAndUpNodeToNodeFancyTransform(a) {
  StatefulDownAndUpNodeToNodeFancyTransform(
    v_before_transforming_children: fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
      Result(#(VXML, a), DesugaringError),
    v_after_transforming_children: fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a, a) ->
      Result(#(VXML, a), DesugaringError),
    t_transform: fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
      Result(#(VXML, a), DesugaringError),
  )
}

fn stateful_down_up_fancy_node_to_node_children_traversal(
  state: a,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: StatefulDownAndUpNodeToNodeFancyTransform(a),
) -> Result(#(List(VXML), List(VXML), List(VXML), a), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, [], state),
      )
    [first, ..rest] -> {
      use #(first_replacement, state) <- result.try(
        stateful_down_up_fancy_node_to_node_one(
          state,
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      stateful_down_up_fancy_node_to_node_children_traversal(
        state,
        ancestors,
        [first, ..previous_siblings_before_mapping],
        [first_replacement, ..previous_siblings_after_mapping],
        rest,
        transform,
      )
    }
  }
}

fn stateful_down_up_fancy_node_to_node_one(
  original_state: a,
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: StatefulDownAndUpNodeToNodeFancyTransform(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    V(_, _, _, children) -> {
      use #(node, state) <- result.try(
        transform.v_before_transforming_children(
          node,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          following_siblings_before_mapping,
          original_state,
        ),
      )

      let assert V(_, _, _, _) = node

      use #(_, reversed_children, _, state) <- result.try(
        stateful_down_up_fancy_node_to_node_children_traversal(
          state,
          [node, ..ancestors],
          [],
          [],
          children,
          transform,
        )
      )

      let node = V(..node, children: reversed_children |> list.reverse)

      transform.v_after_transforming_children(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
        original_state,
        state,
      )
    }

    T(_, _) -> transform.t_transform(
      node,
      ancestors,
      previous_siblings_before_mapping,
      previous_siblings_after_mapping,
      following_siblings_before_mapping,
      original_state,
    )
  }
}

pub fn stateful_down_up_fancy_node_to_node_desugarer_factory(
  transform: StatefulDownAndUpNodeToNodeFancyTransform(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    use #(vxml, _) <- result.try(
      stateful_down_up_fancy_node_to_node_one(
        initial_state,
        vxml,
        [],
        [],
        [],
        [],
        transform,
      )
    )
    Ok(vxml)
  }
}

//**************************************************************
//* desugaring efforts #1.99: stateful down-up node-to-nodes
//**************************************************************

pub type StatefulDownAndUpNodeToNodesTransform(a) {
  StatefulDownAndUpNodeToNodesTransform(
    v_before_transforming_children: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
    v_after_transforming_children: fn(VXML, a, a) ->
      Result(#(List(VXML), a), DesugaringError),
    t_transform: fn(VXML, a) ->
      Result(#(List(VXML), a), DesugaringError),
  )
}

fn stateful_down_up_node_to_nodes_many(
  state: a,
  vxmls: List(VXML),
  transform: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
  case vxmls {
    [] -> Ok(#([], state))
    [first, ..rest] -> {
      use #(first_transformed, new_state) <- result.try(
        stateful_down_up_node_to_nodes_one(state, first, transform),
      )
      use #(rest_transformed, new_new_state) <- result.try(
        stateful_down_up_node_to_nodes_many(new_state, rest, transform),
      )
      Ok(#(list.flatten([first_transformed, rest_transformed]), new_new_state))
    }
  }
}

fn stateful_down_up_node_to_nodes_one(
  original_state: a,
  node: VXML,
  transform: StatefulDownAndUpNodeToNodesTransform(a),
) -> Result(#(List(VXML), a), DesugaringError) {
   case node {
    V(_, _, _, children) -> {
      use #(node, state) <- result.try(
        transform.v_before_transforming_children(
          node,
          original_state,
        ),
      )

      use #(children, state) <- result.try(stateful_down_up_node_to_nodes_many(
        state,
        children,
        transform,
      ))

      transform.v_after_transforming_children(
        node |> infra.replace_children_with(children),
        original_state,
        state,
      )
    }
    T(_, _) -> transform.t_transform(node, original_state)
  }
}

pub fn stateful_down_up_node_to_nodes_desugarer_factory(
  transform: StatefulDownAndUpNodeToNodesTransform(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    case stateful_down_up_node_to_nodes_one(initial_state, vxml, transform) {
      Error(err) -> Error(err)
      Ok(#(new_vxml, _)) -> {
        let assert [new_vxml] = new_vxml
        Ok(new_vxml)
      }
    }
  }
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
  vxmls
  |> list.map(depth_first_node_to_nodes_desugar_one(_, transform))
  |> result.all
  |> result.map(list.flatten)
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

pub fn node_to_nodes_desugarer_factory(
  transform: NodeToNodesTransform,
) -> DesugarerTransform {
  fn(root: VXML) {
    use vxmls <- result.try(depth_first_node_to_nodes_desugar_one(
      root,
      transform,
    ))

    case infra.get_root(vxmls) {
      Ok(r) -> Ok(r)
      Error(message) -> Error(DesugaringError(blamedlines.empty_blame(), message))
    }
  }
}

//**************************************************************
//* desugaring efforts #3: breadth-first-search, node-to-node2 *
//* ; see 'pub' function below                                 *
//**************************************************************

pub type EarlyReturn(a) {
  GoBack(a)
  Continue(a)
  Err(DesugaringError)
}

pub type EarlyReturnNodeToNodeTransform =
  fn(VXML, List(VXML)) -> EarlyReturn(VXML)

fn early_return_node_to_node_desugar_many(
  vxmls: List(VXML),
  ancestors: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(List(VXML), DesugaringError) {
  vxmls
  |> list.map(early_return_node_to_node_desugar_one(_, ancestors, transform))
  |> result.all
}

fn early_return_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  transform: EarlyReturnNodeToNodeTransform,
) -> Result(VXML, DesugaringError) {
  case transform(node, ancestors) {
    GoBack(new_node) -> Ok(new_node)
    Continue(new_node) -> {
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

pub fn early_return_node_to_node_desugarer_factory(
  transform: EarlyReturnNodeToNodeTransform,
) -> DesugarerTransform {
  early_return_node_to_node_desugar_one(_, [], transform)
}
