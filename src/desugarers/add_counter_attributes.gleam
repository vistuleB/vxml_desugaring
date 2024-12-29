import blamedlines.{type Blame}
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
} as infra
import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

fn produce_attributes_and_increase_counters_for_tag(
  blame: Blame,
  counters: Dict(String, Int),
) -> #(Dict(String, Int), List(BlamedAttribute)) {
  counters
  |> dict.to_list
  |> list.map_fold(from: counters, with: fn(current_counters, pair) {
    let #(counter_name, counter_value) = pair
    let new_attribute =
      BlamedAttribute(blame, counter_name, int.to_string(counter_value))
    let new_current_counters =
      dict.insert(current_counters, counter_name, counter_value + 1)
    #(new_current_counters, new_attribute)
  })
}

fn possibly_add_counter_attribute(
  tag: String,
  blame: Blame,
  state: CountingState,
  attributes: List(BlamedAttribute),
) -> #(List(BlamedAttribute), CountingState) {
  case dict.get(state, tag) {
    Error(_) -> #(attributes, state)
    Ok(counters_dict) -> {
      let #(new_counters_dict, attributes_to_add) =
        produce_attributes_and_increase_counters_for_tag(blame, counters_dict)
      #(
        list.flatten([attributes, attributes_to_add]),
        dict.insert(state, tag, new_counters_dict),
      )
    }
  }
}

fn introduce_new_counter_nodes_for_parent(
  parent: String,
  transform_extra: Dict(String, List(TagInfoForParent)),
  counting_state: CountingState,
) -> CountingState {
  case dict.get(transform_extra, parent) {
    Error(_) -> counting_state
    Ok(tag_infos) -> {
      tag_infos
      |> list.map_fold(
        from: counting_state,
        with: fn(current_dict, tag_info) -> #(CountingState, Nil) {
          let #(tag, counter_name, counter_initial_value) = tag_info
          case dict.get(current_dict, tag) {
            Error(Nil) -> {
              dict.insert(
                current_dict,
                tag,
                dict.from_list([#(counter_name, counter_initial_value)]),
              )
            }
            Ok(tag_dict) -> {
              let new_tag_dict =
                dict.insert(tag_dict, counter_name, counter_initial_value)
              dict.insert(current_dict, tag, new_tag_dict)
            }
          }
          |> pair.new(Nil)
        },
      )
      |> pair.first
    }
  }
}

fn param_transform_first_half(
  node: VXML,
  state: CountingState,
  transform_extra: TransformExtra,
) -> Result(#(VXML, CountingState), DesugaringError) {
  case node {
    T(_, _) -> Ok(#(node, state))
    V(blame, tag, attributes, children) -> {
      let new_state =
        introduce_new_counter_nodes_for_parent(tag, transform_extra, state)
      let #(new_attributes, new_new_state) =
        possibly_add_counter_attribute(tag, blame, new_state, attributes)
      Ok(#(V(blame, tag, new_attributes, children), new_new_state))
    }
  }
}

fn revert_new_counter_nodes_for_parent(
  parent: String,
  original_counting_state: CountingState,
  counting_state_given_from_children: CountingState,
  transform_extra: Dict(String, List(TagInfoForParent)),
) -> CountingState {
  case dict.get(transform_extra, parent) {
    Error(_) -> counting_state_given_from_children
    Ok(tag_infos) -> {
      list.map_fold(
        over: tag_infos,
        from: counting_state_given_from_children,
        with: fn(current_dict, tag_info) -> #(CountingState, Nil) {
          io.debug(current_dict)
          let #(tag, counter_name, _) = tag_info
          case dict.get(original_counting_state, tag) {
            Error(Nil) -> #(dict.delete(current_dict, tag), Nil)
            Ok(original_counter_value_dict) -> {
              let assert Ok(current_name_values_for_tag) =
                dict.get(current_dict, tag)
              let new_name_values_for_tag = {
                current_name_values_for_tag
                |> dict.to_list
                |> list.map_fold(
                  from: original_counter_value_dict,
                  with: fn(
                    rewritten_counter_value_dict: Dict(String, Int),
                    pair: #(String, Int),
                  ) -> #(Dict(String, Int), Nil) {
                    let #(name, value) = pair
                    case name == counter_name {
                      True -> #(rewritten_counter_value_dict, Nil)
                      False ->
                        case dict.get(original_counter_value_dict, name) {
                          Error(Nil) ->
                            panic as "thought child would not let leak something to us that they created"
                          Ok(_) -> #(
                            dict.insert(
                              rewritten_counter_value_dict,
                              name,
                              value,
                            ),
                            Nil,
                          )
                        }
                    }
                    |> pair.first
                    |> pair.new(Nil)
                  },
                )
                |> pair.first
              }
              #(dict.insert(current_dict, tag, new_name_values_for_tag), Nil)
            }
          }
        },
      )
      |> pair.first
    }
  }
}

fn param_transform_second_half(
  node: VXML,
  original_state: CountingState,
  state_after_processing_children: CountingState,
  transform_extra: TransformExtra,
) -> Result(#(VXML, CountingState), DesugaringError) {
  case node {
    T(_, _) -> {
      let assert True = state_after_processing_children == original_state
      Ok(#(node, original_state))
    }
    V(_, tag, _, _) -> {
      let new_counting_state =
        dict.combine(
          original_state,
          state_after_processing_children,
          with: fn(_, new_val) { new_val },
        )
      let new_new_counting_state =
        revert_new_counter_nodes_for_parent(
          tag,
          original_state,
          new_counting_state,
          transform_extra,
        )
      Ok(#(node, new_new_counting_state))
    }
  }
}

type TagInfoForParent =
  #(String, String, Int)

fn add_new_tag_info(
  dict: Dict(String, List(TagInfoForParent)),
  parent: String,
  tag: String,
  counter_name: String,
  initial_value: Int,
) -> Dict(String, List(TagInfoForParent)) {
  let new_tag_info_for_parent = #(tag, counter_name, initial_value)
  case dict.get(dict, parent) {
    Error(Nil) -> dict.insert(dict, parent, [new_tag_info_for_parent])
    Ok(tag_infos_for_parent) -> {
      let assert False = list.is_empty(tag_infos_for_parent)
      case
        list.any(tag_infos_for_parent, fn(tag_info_for_parent) {
          let #(this_tag, _, _) = tag_info_for_parent
          this_tag == tag
        })
      {
        True -> {
          let error_msg =
            "tag '"
            <> tag
            <> "' has duplicate parent info for parent '"
            <> parent
            <> "'"
          panic as error_msg
        }
        False -> Nil
      }
      dict.insert(dict, parent, [
        new_tag_info_for_parent,
        ..tag_infos_for_parent
      ])
    }
  }
}

fn map_folder(
  dict: Dict(String, List(TagInfoForParent)),
  tuple: #(String, String, String, Int),
) -> #(Dict(String, List(TagInfoForParent)), Nil) {
  let #(tag, parent, counter_name, counter_initial_value) = tuple
  #(
    add_new_tag_info(dict, parent, tag, counter_name, counter_initial_value),
    Nil,
  )
}

fn transform_extra_dictionary(extra: Extra) -> TransformExtra {
  list.map_fold(over: extra, from: dict.from_list([]), with: map_folder)
  |> pair.first
}

//**********************************
// type Extra = List(#(String,         String,                         String,              Int))
//                       ↖ tag            ↖ parent (aka, ancestor)        ↖ attribute        ↖ initial
//                                          that cause this                 name for           value for
//                                          tag extra to reset              counter under      that parent
//                                          to an initial                   that parent
//                                          value, and for a
//                                          count to occur
//**********************************
type Extra =
  List(#(String, String, String, Int))

//**********************************
// the semantcs of 'CountingState':
//
// Dict(String,    #(String,         Int))
//       ↖ tag        ↖ current       ↖ current
//                      attribute       value
//                      name
//**********************************
type CountingState =
  Dict(String, Dict(String, Int))

//**********************************
// '\' is the static portion
// of the transform state, that does not change
// for the entire tree-traversal; it is a re-encoding
// of 'Extra' in the form of a dictionary that
// indexes on the parent name, giving the list
// of affected tags for each parent name:
//
// Dict(String,      List(                 #(String,            String,                Int))
//       ↖ parent      ↖ list of               ↖ tag              ↖ attribute           ↖ initial value
//                       tags for which          name               name to use           to use for this
//                       the parent causes                          for this parent       parent
//                       a count to occur
//**********************************
type TransformExtra =
  Dict(String, List(TagInfoForParent))

fn transform_factory(
  extra: Extra,
) -> infra.StatefulDownAndUpNodeToNodeTransform(CountingState) {
  let transform_extra = transform_extra_dictionary(extra)
  infra.StatefulDownAndUpNodeToNodeTransform(
    before_transforming_children: fn(node, state) {
      param_transform_first_half(node, state, transform_extra)
    },
    after_transforming_children: fn(node, old_state, new_state) {
      param_transform_second_half(node, old_state, new_state, transform_extra)
    },
  )
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  let initial_state: CountingState = dict.from_list([])
  infra.stateful_down_up_node_to_node_desugarer_factory(
    transform_factory(extra),
    initial_state,
  )
}

pub fn add_counter_attributes(extra: Extra) -> Pipe {
  #(
    DesugarerDescription(
      "add_counter_attributes",
      option.Some(string.inspect(extra)),
      "...",
    ),
    desugarer_factory(extra),
  )
}
