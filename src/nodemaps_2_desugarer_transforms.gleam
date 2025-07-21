import gleam/result
import gleam/list
import vxml.{type VXML, V, T}
import infrastructure.{type DesugarerTransform, type DesugaringError} as infra

//**************************************************************
//* OneToOneNodeMapNoError
//**************************************************************

pub type OneToOneNodeMapNoError =
  fn(VXML) -> VXML

fn one_to_one_nodemap_no_error_recursive_application(
  node: VXML,
  nodemap: OneToOneNodeMapNoError,
) -> VXML {
  case node {
    T(_, _) -> nodemap(node)
    V(_, _, _, children) -> nodemap(V(
      ..node,
      children: list.map(children, one_to_one_nodemap_no_error_recursive_application(_, nodemap))
    ))
  }
}

pub fn one_to_one_nodemap_no_error_2_desugarer_transform(
  nodemap: OneToOneNodeMapNoError,
) -> DesugarerTransform {
  fn (vxml) {
    one_to_one_nodemap_no_error_recursive_application(vxml, nodemap)
    |> Ok
  }
}

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
        |> list.try_map(one_to_many_nodemap_recursive_application(_, nodemap))
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
      let children_ancestors = [node, ..ancestors]
      use children <- result.try(
        list.try_fold(
          children,
          #([], [], list.drop(children, 1)),
          fn(acc, child) {
            case fancy_one_to_one_nodemap_recursive_application(child, children_ancestors, acc.0, acc.1, acc.2, nodemap) {
              Error(e) -> Error(e)
              Ok(mapped_child) -> {
                Ok(#(
                  [child, ..acc.0],
                  [mapped_child, ..acc.1],
                  list.drop(acc.2, 1),
                ))
              }
            }
          }
        )
        |> result.map(fn(acc) {acc.1 |> list.reverse})
      )
      nodemap(
        V(blame, tag, attrs, children),
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

fn fancy_one_to_many_nodemap_recursive_application(
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  nodemap: FancyOneToManyNodeMap,
) -> Result(List(VXML), DesugaringError) {
  case node {
    T(_, _) ->
      nodemap(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    V(_, _, _, children) -> {
      let children_ancestors = [node, ..ancestors]
      use children <- result.try(
        list.try_fold(
          children,
          #([], [], list.drop(children, 1)),
          fn(acc, child) {
            case fancy_one_to_many_nodemap_recursive_application(
              child,
              children_ancestors,
              acc.0,
              acc.1,
              acc.2,
              nodemap
            ) {
              Error(e) -> Error(e)
              Ok(shat_children) -> {
                Ok(#(
                  [child, ..acc.0],
                  infra.pour(shat_children, acc.1),
                  list.drop(acc.2, 1),
                ))
              }
            }
          }
        )
        |> result.map(fn(acc) {acc.1 |> list.reverse})
      )
      nodemap(
        V(..node, children: children),
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
      )
    }
  }
}

pub fn fancy_one_to_many_nodemap_2_desugarer_transform(
  nodemap: FancyOneToManyNodeMap,
) -> DesugarerTransform {
  fn(root: VXML) {
    fancy_one_to_many_nodemap_recursive_application(
      root,
      [],
      [],
      [],
      [],
      nodemap
    )
    |> result.try(infra.get_root_with_desugaring_error)
  }
}

//**************************************************************
//* OneToOneStatefulNodeMap
//**************************************************************

pub type OneToOneStatefulNodeMap(a) =
  fn(VXML, a) -> Result(#(VXML, a), DesugaringError)

fn one_to_one_stateful_nodemap_recursive_application(
  state: a,
  node: VXML,
  nodemap: OneToOneStatefulNodeMap(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> nodemap(node, state)
    V(_, _, _, children) -> {
      use #(children, state) <- result.try(
        children
        |> infra.try_map_fold(
          state,
          fn(acc, child) {
            one_to_one_stateful_nodemap_recursive_application(acc, child, nodemap)
          }
        )
      )
      nodemap(V(..node, children: children), state)
    }
  }
}

pub fn one_to_one_stateful_nodemap_2_desugarer_transform(
  nodemap: OneToOneStatefulNodeMap(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    case one_to_one_stateful_nodemap_recursive_application(initial_state, vxml, nodemap) {
      Error(err) -> Error(err)
      Ok(#(new_vxml, _)) -> Ok(new_vxml)
    }
  }
}

//**********************************************************************
//* FancyOneToOneStatefulNodeMap
//**********************************************************************

pub type FancyOneToOneStatefulNodeMap(a) =
  fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
    Result(#(VXML, a), DesugaringError)

fn fancy_one_to_one_stateful_nodemap_recursive_application(
  state: a,
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  nodemap: FancyOneToOneStatefulNodeMap(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) ->
      nodemap(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
        state,
      )
    V(_, _, _, children) -> {
      let children_ancestors = [node, ..ancestors]
      use #(children, state) <- result.try(
        list.try_fold(
          children,
          #([], [], list.drop(children, 1), state),
          fn(acc, child) {
            case fancy_one_to_one_stateful_nodemap_recursive_application(
              acc.3,
              child,
              children_ancestors,
              acc.0,
              acc.1,
              acc.2,
              nodemap,
            ) {
              Error(e) -> Error(e)
              Ok(#(mapped_child, state)) -> {
                Ok(#(
                  [child, ..acc.0],
                  [mapped_child],
                  list.drop(acc.2, 1),
                  state,
                ))
              }
            }
          }
        )
        |> result.map(fn(acc) {#(acc.1 |> list.reverse, acc.3)})
      )
      nodemap(
        V(..node, children: children),
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
        state,
      )
    }
  }
}

pub fn fancy_one_to_one_stateful_nodemap_2_desugarer_transform(
  nodemap: FancyOneToOneStatefulNodeMap(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    case fancy_one_to_one_stateful_nodemap_recursive_application(
      initial_state,
      vxml,
      [],
      [],
      [],
      [],
      nodemap,
    ) {
      Error(err) -> Error(err)
      Ok(#(vxml, _)) -> Ok(vxml)
    }
  }
}

//**********************************************************************
//* OneToOneBeforeAndAfterStatefulNodeMap
//**********************************************************************

pub type OneToOneBeforeAndAfterStatefulNodeMap(a) {
  OneToOneBeforeAndAfterStatefulNodeMap(
    v_before_transforming_children: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
    v_after_transforming_children: fn(VXML, a, a) ->
      Result(#(VXML, a), DesugaringError),
    t_nodemap: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
  )
}

fn one_to_one_before_and_after_stateful_nodemap_recursive_application(
  original_state: a,
  node: VXML,
  nodemap: OneToOneBeforeAndAfterStatefulNodeMap(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> nodemap.t_nodemap(node, original_state)
    V(_, _, _, children) -> {
      use #(node, latest_state) <- result.try(
        nodemap.v_before_transforming_children(
          node,
          original_state,
        ),
      )
      use #(children, latest_state) <- result.try(
        infra.try_map_fold(
          children,
          latest_state,
          fn (acc, child) { one_to_one_before_and_after_stateful_nodemap_recursive_application(acc, child, nodemap) }
        )
      )
      nodemap.v_after_transforming_children(
        node |> infra.replace_children_with(children),
        original_state,
        latest_state,
      )
    }
  }
}

pub fn one_to_one_before_and_after_stateful_nodemap_2_desugarer_transform(
  nodemap: OneToOneBeforeAndAfterStatefulNodeMap(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    use #(vxml, _) <- result.try(
      one_to_one_before_and_after_stateful_nodemap_recursive_application(
        initial_state,
        vxml,
        nodemap
      )
    )
    Ok(vxml)
  }
}

//**********************************************************************
//* FancyOneToOneBeforeAndAfterStatefulNodeMap(a)
//**********************************************************************

pub type FancyOneToOneBeforeAndAfterStatefulNodeMap(a) {
  FancyOneToOneBeforeAndAfterStatefulNodeMap(
    v_before_transforming_children: fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
      Result(#(VXML, a), DesugaringError),
    v_after_transforming_children: fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a, a) ->
      Result(#(VXML, a), DesugaringError),
    t_nodemap: fn(VXML, List(VXML), List(VXML), List(VXML), List(VXML), a) ->
      Result(#(VXML, a), DesugaringError),
  )
}

fn fancy_one_to_one_before_and_after_stateful_nodemap_recursive_application(
  original_state: a,
  node: VXML,
  ancestors: List(VXML),
  previous_siblings_before_mapping: List(VXML),
  previous_siblings_after_mapping: List(VXML),
  following_siblings_before_mapping: List(VXML),
  nodemap: FancyOneToOneBeforeAndAfterStatefulNodeMap(a),
) -> Result(#(VXML, a), DesugaringError) {
  case node {
    T(_, _) -> nodemap.t_nodemap(
      node,
      ancestors,
      previous_siblings_before_mapping,
      previous_siblings_after_mapping,
      following_siblings_before_mapping,
      original_state,
    )
    V(_, _, _, _) -> {
      use #(node, latest_state) <- result.try(
        nodemap.v_before_transforming_children(
          node,
          ancestors,
          previous_siblings_before_mapping,
          previous_siblings_after_mapping,
          following_siblings_before_mapping,
          original_state,
        ),
      )
      let assert V(_, _, _, children) = node
      let children_ancestors = [node, ..ancestors]
      use #(children, latest_state) <- result.try(
        list.try_fold(
          children,
          #([], [], list.drop(children, 1), latest_state),
          fn (acc, child) {
            use #(mapped_child, state) <- result.try(fancy_one_to_one_before_and_after_stateful_nodemap_recursive_application(
              acc.3,
              child,
              children_ancestors,
              acc.0,
              acc.1,
              acc.2,
              nodemap,
            ))
            Ok(#(
              [child, ..acc.0],
              [mapped_child, ..acc.1],
              list.drop(acc.2, 1),
              state,
            ))
          }
        )
        |> result.map(fn(acc){#(acc.1 |> list.reverse, acc.3)})
      )
      let node = V(..node, children: children)
      nodemap.v_after_transforming_children(
        node,
        ancestors,
        previous_siblings_before_mapping,
        previous_siblings_after_mapping,
        following_siblings_before_mapping,
        original_state,
        latest_state,
      )
    }
  }
}

pub fn fancy_one_to_one_before_and_after_stateful_nodemap_2_desugarer_transform(
  nodemap: FancyOneToOneBeforeAndAfterStatefulNodeMap(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    use #(vxml, _) <- result.try(
      fancy_one_to_one_before_and_after_stateful_nodemap_recursive_application(
        initial_state,
        vxml,
        [],
        [],
        [],
        [],
        nodemap,
      )
    )
    Ok(vxml)
  }
}

//**************************************************************
//* OneToManyBeforeAndAfterStatefulNodeMap
//**************************************************************

pub type OneToManyBeforeAndAfterStatefulNodeMap(a) {
  OneToManyBeforeAndAfterStatefulNodeMap(
    v_before_transforming_children: fn(VXML, a) ->
      Result(#(VXML, a), DesugaringError),
    v_after_transforming_children: fn(VXML, a, a) ->
      Result(#(List(VXML), a), DesugaringError),
    t_nodemap: fn(VXML, a) ->
      Result(#(List(VXML), a), DesugaringError),
  )
}

fn one_to_many_before_and_after_stateful_nodemap_recursive_application(
  original_state: a,
  node: VXML,
  nodemap: OneToManyBeforeAndAfterStatefulNodeMap(a),
) -> Result(#(List(VXML), a), DesugaringError) {
   case node {
    V(_, _, _, _) -> {
      use #(node, latest_state) <- result.try(
        nodemap.v_before_transforming_children(
          node,
          original_state,
        ),
      )
      let assert V(_, _, _, children) = node
      use #(children, latest_state) <- result.try(
        children
        |> list.try_fold(
          #([], latest_state),
          fn (acc, child) {
            use #(shat_children, latest_state) <- result.try(one_to_many_before_and_after_stateful_nodemap_recursive_application(
              acc.1,
              child,
              nodemap,
            ))
            Ok(#(
              infra.pour(shat_children, acc.0),
              latest_state,
            ))
          }
        )
        |> result.map(fn(acc) {#(acc.0 |> list.reverse, acc.1)})
      )
      nodemap.v_after_transforming_children(
        node |> infra.replace_children_with(children),
        original_state,
        latest_state,
      )
    }
    T(_, _) -> nodemap.t_nodemap(node, original_state)
  }
}

pub fn one_to_many_before_and_after_stateful_nodemap_2_desufarer_transform(
  nodemap: OneToManyBeforeAndAfterStatefulNodeMap(a),
  initial_state: a,
) -> DesugarerTransform {
  fn(vxml) {
    one_to_many_before_and_after_stateful_nodemap_recursive_application(initial_state, vxml, nodemap)
    |> result.map(fn(pair){pair.0})
    |> result.try(infra.get_root_with_desugaring_error)
  }
}

//**************************************************************
//* EarlyReturn land... renaming not yet done...
//**************************************************************

pub type TrafficLight {
  Green
  Red
}

pub type EarlyReturnOneToOneNodeMap =
  fn(VXML, List(VXML)) -> Result(#(VXML, TrafficLight), DesugaringError)

fn early_return_one_to_one_nodemap_recursive_application(
  node: VXML,
  ancestors: List(VXML),
  nodemap: EarlyReturnOneToOneNodeMap,
) -> Result(VXML, DesugaringError) {
  use #(node, color) <- result.try(nodemap(node, ancestors))
  case node, color {
    _, Red -> Ok(node)
    T(_, _), _ -> Ok(node)
    V(_, _, _, children), Green -> {
      let children_ancestors = [node, ..ancestors]
      use children <- result.try(
        children
        |> list.try_map(early_return_one_to_one_nodemap_recursive_application(_, children_ancestors, nodemap))
      )
      Ok(V(..node, children: children))
    }
  }
}

pub fn early_return_node_to_node_desugarer_factory(
  nodemap: EarlyReturnOneToOneNodeMap,
) -> DesugarerTransform {
  early_return_one_to_one_nodemap_recursive_application(_, [], nodemap)
}

//**********************************************************************
//* misc: turn OneToOneNodeMap into parent-avoiding fancy transform                               *
//**********************************************************************

pub fn list_intersection(l1: List(a), l2: List(a)) -> Bool {
  list.any(l1, list.contains(l2, _))
}

pub fn prevent_node_to_node_transform_inside(
  nodemap: OneToOneNodeMap,
  forbidden_tags: List(String),
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
      V(_, tag, _, _) -> list.contains(forbidden_tags, tag)
    }
    case node_is_forbidden_tag  || list_intersection(ancestors|> list.map(infra.get_tag), forbidden_tags)
    {
      False -> nodemap(node)
      True -> Ok(node)
    }
  }
}

pub fn prevent_one_to_many_nodemap_inside(
  nodemap: OneToManyNodeMap,
  forbidden_tags: List(String),
) -> FancyOneToManyNodeMap {
  fn(
    node: VXML,
    ancestors: List(VXML),
    _: List(VXML),
    _: List(VXML),
    _: List(VXML),
  ) -> Result(List(VXML), DesugaringError) {
    case list_intersection(ancestors|> list.map(infra.get_tag), forbidden_tags)
    {
      False -> nodemap(node)
      True -> Ok([node])
    }
  }
}
