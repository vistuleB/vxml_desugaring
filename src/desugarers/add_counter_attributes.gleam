// import gleam/dict.{type Dict}
// import gleam/list
// import gleam/option
// import gleam/pair
// import gleam/string
// import infrastructure.{
//   type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
// } as infra
// import vxml_parser.{type BlamedAttribute, type VXML, BlamedAttribute, T, V}

// fn build_blamed_attributes(
//   blame,
//   attributes: List(#(String, String)),
// ) -> List(BlamedAttribute) {
//   attributes
//   |> list.map(fn(attr) {
//     BlamedAttribute(blame, attr |> pair.first, attr |> pair.second)
//   })
// }

// fn param_transform(
//   node: VXML,
//   state: CountingState,
//   transform_extra: TransformExtra,
// ) -> Result(#(VXML, CountingState), DesugaringError) {
//   case node {
//     T(_, _) -> Ok(#(node, state))
//     V(blame, tag, attributes, children) -> {
//       let #(new_attributes, new_counting_state) = possibly_add_counter_attribute(tag, state, attributes)
//       let new_new_counting_state
//     }
//   }
// }

// fn initial_state(extra: Extra) -> CountingState {
//   extra
//   |> list.map(fn(tuple) {
//     let #(tag, _, attribute_name, initial_value) = tuple
//     #(tag, #(attribute_name, initial_value))
//   })
//   |> dict.from_list
// }

// fn add_to_dict_list_value(
//   dict: Dict(a, List(b)),
//   key: a,
//   new_value: b,
// ) -> Dict(a, List(b)) {
//   case dict.get(dict, key) {
//     Error(Nil) -> dict.insert(dict, key, [new_value])
//     Ok(values) ->
//       case list.contains(values, new_value) {
//         True -> dict
//         False -> dict.insert(dict, key, [new_value, ..values])
//       }
//   }
// }

// fn add_new_parent_info(
//   dict: Dict(String, List(TagInfoForParent)),
//   tag: String,
//   parent_info: ParentInfoForTag,
// ) -> Dict(String, List(TagInfoForParent)) {
//   let #(parent, attribute_name, initial_value) = parent_info
//   let new_tag_info_for_parent = #(tag, attribute_name, initial_value)
//   case dict.get(dict, parent) {
//     Error(Nil) -> dict.insert(dict, parent, [new_tag_info_for_parent])
//     Ok(tag_infos_for_parent) -> {
//       let assert False = list.is_empty(tag_infos_for_parent)
//       case
//         list.any(tag_infos_for_parent, fn(tag_info_for_parent) {
//           let #(this_tag, _, _) = tag_info_for_parent
//           this_tag == tag
//         })
//       {
//         True -> {
//           let error_msg =
//             "tag '"
//             <> tag
//             <> "' has duplicate parent info for parent '"
//             <> parent
//             <> "'"
//           panic as error_msg
//         }
//         False -> Nil
//       }
//       dict.insert(dict, parent, [
//         new_tag_info_for_parent,
//         ..tag_infos_for_parent
//       ])
//     }
//   }
// }

// fn make_inner_map_fold_reducer(
//   tag: String,
// ) -> fn(Dict(String, List(TagInfoForParent)), ParentInfoForTag) ->
//   #(Dict(String, List(TagInfoForParent)), Nil) {
//   fn(dict, parent_info) { #(add_new_parent_info(dict, tag, parent_info), Nil) }
// }

// type ParentInfoForTag =
//   #(String, String, Int)

// type TagInfoForParent =
//   #(String, String, Int)

// fn map_fold_reducer(
//   dict: Dict(String, List(TagInfoForParent)),
//   tuple: #(String, List(ParentInfoForTag)),
// ) -> #(Dict(String, List(TagInfoForParent)), Nil) {
//   let #(tag, parents_info) = tuple
//   list.map_fold(
//     over: parents_info,
//     from: dict,
//     with: make_inner_map_fold_reducer(tag),
//   )
//   |> pair.first
//   |> pair.new(Nil)
// }

// fn transform_extra_dictionary(extra: Extra) -> TransformExtra {
//   let ze_initial_dict: Dict(String, TagInfoForParent) = dict.from_list([])
//   list.map_fold(over: extra, from: ze_initial_dict, with: map_fold_reducer)
//   |> pair.first
// }

// //**********************************
// // type Extra = List(#(String,         String,                         String,              Int))
// //                       ↖ tag            ↖ parent (aka, ancestor)        ↖ attribute        ↖ initial
// //                                          that cause this                 name for           value for
// //                                          tag extra to reset              counter under      that parent
// //                                          to an initial                   that parent
// //                                          value, and for a
// //                                          count to occur
// //**********************************
// type Extra =
//   List(#(String, String, String, Int))

// //**********************************
// // the semantcs of 'CountingState':
// //
// // Dict(String,    #(String,         Int))
// //       ↖ tag        ↖ current       ↖ current
// //                      attribute       value
// //                      name
// //**********************************
// type CountingState =
//   Dict(String, #(String, Int))

// //**********************************
// // '\' is the static portion
// // of the transform state, that does not change
// // for the entire tree-traversal; it is a re-encoding
// // of 'Extra' in the form of a dictionary that
// // indexes on the parent name, giving the list
// // of affected tags for each parent name:
// //
// // Dict(String,      List(                 #(String,            String,                Int))
// //       ↖ parent      ↖ list of               ↖ tag              ↖ attribute           ↖ initial value
// //                       tags for which          name               name to use           to use for this
// //                       the parent causes                          for this parent       parent
// //                       a count to occur
// //**********************************
// type TransformExtra =
//   Dict(String, List(TagInfoForParent))

// fn transform_factory(
//   extra: Extra,
// ) -> infra.StatefulNodeToNodeTransform(CountingState) {
//   let transform_extra = transform_extra_dictionary(extra)
//   fn(node, state) { param_transform(node, state, transform_extra) }
// }

// fn desugarer_factory(extra: Extra) -> Desugarer {
//   infra.stateful_node_to_node_desugarer_factory(
//     transform_factory(extra),
//     initial_state(extra),
//   )
// }

// pub fn add_counter_attributes(extra: Extra) -> Pipe {
//   #(
//     DesugarerDescription(
//       "add_counter_attributes",
//       option.Some(string.inspect(extra)),
//       "...",
//     ),
//     desugarer_factory(extra),
//   )
// }
