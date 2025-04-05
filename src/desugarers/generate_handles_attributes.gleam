import gleam/list
import gleam/option
import gleam/string
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}



fn param_transform_first_half(
  node: VXML,
  state: State,
  extra: Extra,
) -> Result(#(VXML, State), DesugaringError) {
  let #(parent_tag, target_tag) = extra
  case node {
    T(_, _) -> Ok(#(node, state))
    V(_, tag, _, _)  -> {
      let #(ch_number, ex_number) = state
      case tag  {
        t if t == parent_tag -> Ok(#(node, #(ch_number + 1, 0))) // should reset ex_number to 1
        t if t == target_tag -> Ok(#(node, #(ch_number, ex_number + 1)))
        _ -> Ok(#(node, state))
      }
    }
  }
}

fn param_transform_second_half(
  node: VXML,
  original_state: State,
  state_after_processing_children: State,
  extra: Extra,
) -> Result(#(VXML, State), DesugaringError) {
  let #(parent_tag, target_tag) = extra
  case node {
    T(_, _) -> {
      let assert True = state_after_processing_children == original_state
      Ok(#(node, original_state))
    }
    V(b, tag, attributes, children) -> {
      let #(ch_number, ex_number) = state_after_processing_children

      case tag == target_tag && ch_number > 0 {
        True -> {
          let attributes = list.append(
            attributes,
            [vxml.BlamedAttribute(
              b,
              "handle",
              string.concat([parent_tag, string.inspect(ch_number), target_tag, string.inspect(ex_number)]),
            )],
          )
          Ok(#(V(b, tag, attributes, children), state_after_processing_children))
        }
        False -> Ok(#(node, state_after_processing_children))
      }
    }
  }
}

//**********************************
// type Extra = List(#(String,                         String,              Int))
//                      ↖ parent (aka, ancestor)        ↖                    ↖ initial
//                       that cause this                   tag                 value for
//                       tag extra to reset                                    that parent
//                       to an initial                      
//                       value, and for a
//                       count to occur
//**********************************
type Extra =
  #(String, String)

// Chapter number, Exercise number
type State = #(Int, Int)

fn transform_factory(
  extra: Extra,
) -> infra.StatefulDownAndUpNodeToNodeTransform(#(Int, Int)) {
  infra.StatefulDownAndUpNodeToNodeTransform(
    before_transforming_children: fn(node, state) {
      param_transform_first_half(node, state, extra)
    },
    after_transforming_children: fn(node, old_state, new_state) {
      param_transform_second_half(node, old_state, new_state, extra)
    },
  )
}

fn desugarer_factory(extra: Extra) -> Desugarer {
  infra.stateful_down_up_node_to_node_desugarer_factory(
    transform_factory(extra),
    #(0, 0),
  )
}

/// take #(ParentTag, TargetTag)
/// Adds attibute (handle ParentTagXTargetTagY)
pub fn generate_handles_attributes(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "generate_handles_attributes",
      option.Some(string.inspect(extra)),
      "take #(ParentTag, TargetTag)\n
      Adds attibute (handle ParentTagXTargetTagY)",
    ),
    desugarer: desugarer_factory(extra),
  )
}
