import gleam/result
import gleam/list
import vxml.{type VXML, V, T}
import infrastructure.{type DesugarerTransform, type DesugaringError} as infra

//**************************************************************
//* OneToOneNodeMap
//**************************************************************

pub type OneToOneNodeMap =
  fn(VXML) -> Result(VXML, DesugaringError)

fn one_to_one_nodemap_recursive_application(
  node: VXML,
  nodemap: OneToOneNodeMap,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) -> nodemap(node)
    V(_, _, _, children) -> {
      use children <- result.try(
        children
        |> list.map(one_to_one_nodemap_recursive_application(_, nodemap))
        |> result.all
      )
      nodemap(V(..node, children: children))
    }
  }
}

pub fn one_to_one_nodemap_2_desugarer_transform(
  nodemap: OneToOneNodeMap,
) -> DesugarerTransform {
  one_to_one_nodemap_recursive_application(_, nodemap)
}

//**************************************************************
//* OneToManyNodeMap
//**************************************************************

pub type OneToManyNodeMap =
  fn(VXML) -> Result(List(VXML), DesugaringError)

fn one_to_many_nodemap_recursive_application(
  node: VXML,
  nodemap: OneToManyNodeMap,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) -> nodemap(node)
    V(_, _, _, children) -> {
      use children <- result.try(
        children
        |> list.map(one_to_many_nodemap_recursive_application(_, nodemap))
        |> result.all
        |> result.map(list.flatten)
      )
      nodemap(V(..node, children: children))
    }
  }
}

pub fn one_to_many_nodemap_2_desugarer_transform(
  nodemap: OneToManyNodeMap,
) -> DesugarerTransform {
  fn (vxml) {
    one_to_many_nodemap_recursive_application(vxml, nodemap)
    |> result.try(infra.get_root_with_desugaring_error)
  }
}

//**************************************************************
//* FancyOneToManyNodeMap
//**************************************************************

pub type FancyOneToOneNodeMap =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(VXML, DesugaringError)

fn fancy_one_to_one_nodemap_children_traversal(
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  nodemap: FancyOneToOneNodeMap,
) -> Result(#(List(VXML), List(VXML), List(VXML)), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, []),
      )
    [first, ..rest] -> {
      use first_replacement <- result.try(
        fancy_one_to_one_nodemap_recursive_application(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          nodemap,
        ),
      )
      fancy_one_to_one_nodemap_children_traversal(
        ancestors,
        [first, ..previous_siblings_before_mapping],
        [first_replacement, ..previous_siblings_after_mapping],
        rest,
        nodemap,
      )
    }
  }
}

fn fancy_one_to_one_nodemap_recursive_application(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  nodemap: FancyOneToOneNodeMap,
) -> Result(VXML, DesugaringError) {
  case node {
    T(_, _) ->
      nodemap(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )

    V(blame, tag, attrs, children) -> {
      use #(_, reversed_children, _) <- result.try(
        fancy_one_to_one_nodemap_children_traversal(
          [node, ..ancestors],
          [],
          [],
          children,
          nodemap,
      ))

      nodemap(
        V(blame, tag, attrs, reversed_children |> list.reverse),
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    }
  }
}

pub fn fancy_one_to_one_nodemap_2_desugarer_transform(
  nodemap: FancyOneToOneNodeMap,
) -> DesugarerTransform {
  fancy_one_to_one_nodemap_recursive_application(_, [], [], [], [], nodemap)
}

//**********************************************************************
//* FancyOneToManyNodeMap
//**********************************************************************

pub type FancyOneToManyNodeMap =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML)) ->
    Result(List(VXML), DesugaringError)

fn fancy_one_to_many_children_traversal(
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: FancyOneToManyNodeMap,
) -> Result(#(List(VXML), List(VXML), List(VXML)), DesugaringError) {
  case following_siblings_before_mapping {
    [] ->
      Ok(
        #(previous_siblings_before_mapping, previous_siblings_after_mapping, []),
      )
    [first, ..rest] -> {
      use first_replacement <- result.try(
        fancy_one_to_many_recursive_application(
          first,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          rest,
          transform,
        ),
      )
      fancy_one_to_many_children_traversal(
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

fn fancy_one_to_many_recursive_application(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: FancyOneToManyNodeMap,
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
        fancy_one_to_many_children_traversal(
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

pub fn fancy_one_to_many_nodemap_2_desugarer_transform(
  transform: FancyOneToManyNodeMap,
) -> DesugarerTransform {
  fn(root: VXML) {
    fancy_one_to_many_recursive_application(
      root,
      [],
      [],
      [],
      [],
      transform,
    )
    |> result.try(infra.get_root_with_desugaring_error)
  }
}

//**************************************************************
//* desugaring efforts #1.8: stateful node-to-node
//**************************************************************

pub type StatefulOneToOneNodeMap(a) =
  fn(VXML, a) -> Result(#(VXML, a), DesugaringError)

fn stateful_node_to_node_desugar_one(
  state: a,
  node: VXML,
  transform: StatefulOneToOneNodeMap(a),
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
  transform: StatefulOneToOneNodeMap(a),
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

pub type StatefulFancyOneToOneNodeMap(a) =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
    Result(#(VXML, a), DesugaringError)

fn stateful_fancy_depth_first_node_to_node_children_traversal(
  state: a,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  transform: StatefulFancyOneToOneNodeMap(a),
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
  transform: StatefulFancyOneToOneNodeMap(a),
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
  transform: StatefulFancyOneToOneNodeMap(a),
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

pub type StatefulDownAndUpOneToOneNodeMap(a) {
  StatefulDownAndUpOneToOneNodeMap(
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
  transform: StatefulDownAndUpOneToOneNodeMap(a),
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
  transform: StatefulDownAndUpOneToOneNodeMap(a),
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

pub type StatefulDownAndUpFancyOneToOneNodeMap(a) {
  StatefulDownAndUpFancyOneToOneNodeMap(
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
  transform: StatefulDownAndUpFancyOneToOneNodeMap(a),
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
  transform: StatefulDownAndUpFancyOneToOneNodeMap(a),
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
  transform: StatefulDownAndUpFancyOneToOneNodeMap(a),
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

pub type StatefulDownAndUpOneToManyNodeMap(a) {
  StatefulDownAndUpOneToManyNodeMap(
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
  transform: StatefulDownAndUpOneToManyNodeMap(a),
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
  transform: StatefulDownAndUpOneToManyNodeMap(a),
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
  transform: StatefulDownAndUpOneToManyNodeMap(a),
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

//**************************************************************
//* desugaring efforts #3: breadth-first-search, node-to-node2 *
//* ; see 'pub' function below                                 *
//**************************************************************

pub type EarlyReturn(a) {
  GoBack(a)
  Continue(a)
  Err(DesugaringError)
}

pub type EarlyReturnOneToOneNodeMap =
  fn(VXML, List(VXML)) -> EarlyReturn(VXML)

fn early_return_node_to_node_desugar_many(
  vxmls: List(VXML),
  ancestors: List(VXML),
  transform: EarlyReturnOneToOneNodeMap,
) -> Result(List(VXML), DesugaringError) {
  vxmls
  |> list.map(early_return_node_to_node_desugar_one(_, ancestors, transform))
  |> result.all
}

fn early_return_node_to_node_desugar_one(
  node: VXML,
  ancestors: List(VXML),
  transform: EarlyReturnOneToOneNodeMap,
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
  transform: EarlyReturnOneToOneNodeMap,
) -> DesugarerTransform {
  early_return_node_to_node_desugar_one(_, [], transform)
}


//**********************************************************************
//* desugaring efforts #1.7: turn ordinary node-to-node(s) transform   *
//* into parent-avoiding fancy transform                               *
//**********************************************************************

pub fn prevent_node_to_node_transform_inside(
  transform: OneToOneNodeMap,
  forbidden_tag: List(String),
) -> FancyOneToOneNodeMap {
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
  transform: OneToManyNodeMap,
  neutralize_here: List(String),
) -> FancyOneToManyNodeMap {
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
