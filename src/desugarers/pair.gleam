import gleam/list
import gleam/option.{type Option}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import nodemaps_2_desugarer_transforms as n2t
import vxml.{type VXML, T, V}

fn accumulator(
  opening: String,
  closing: String,
  enclosing: String,
  already_processed: List(VXML),
  last_opening: Option(VXML),
  after_last_opening: List(VXML),
  remaining: List(VXML),
) -> List(VXML) {
  case remaining {
    [] ->
      case last_opening {
        option.None -> {
          let assert [] = after_last_opening
          already_processed |> list.reverse
        }
        option.Some(dude) -> {
          list.flatten([after_last_opening, [dude, ..already_processed]])
          |> list.reverse
        }
      }
    [T(_, _) as first, ..rest] ->
      case last_opening {
        option.None -> {
          // *
          // absorb the T-node into already_processed
          // *
          let assert [] = after_last_opening
          accumulator(
            opening,
            closing,
            enclosing,
            [first, ..already_processed],
            option.None,
            [],
            rest,
          )
        }
        option.Some(_) ->
          // *
          // absorb the T-node into after_last_opening
          // *
          accumulator(
            opening,
            closing,
            enclosing,
            already_processed,
            last_opening,
            [first, ..after_last_opening],
            rest,
          )
      }
    [V(_, tag, _, _) as first, ..rest] ->
      case tag == opening, tag == closing {
        False, False ->
          // *
          // treat the V-node like the T-node above
          // *
          case last_opening {
            option.None -> {
              // *
              // absorb the V-node into already_processed
              // *
              let assert [] = after_last_opening
              accumulator(
                opening,
                closing,
                enclosing,
                [first, ..already_processed],
                option.None,
                [],
                rest,
              )
            }
            option.Some(_) ->
              // *
              // absorb the V-node into after_last_opening
              // *
              accumulator(
                opening,
                closing,
                enclosing,
                already_processed,
                last_opening,
                [first, ..after_last_opening],
                rest,
              )
          }
        True, False ->
          case last_opening {
            option.None -> {
              // *
              // we make the V-node the new value of last_opening
              // *
              let assert [] = after_last_opening
              accumulator(
                opening,
                closing,
                enclosing,
                already_processed,
                option.Some(first),
                [],
                rest,
              )
            }
            option.Some(dude) ->
              // *
              // we discard the previous last_opening and his followers and make the V-node the new value of last_opening
              // *
              accumulator(
                opening,
                closing,
                enclosing,
                list.flatten([after_last_opening, [dude, ..already_processed]]),
                option.Some(first),
                [],
                rest,
              )
          }
        False, True ->
          case last_opening {
            option.None -> {
              // *
              // we absorb the V-node into already_processed
              // *
              let assert [] = after_last_opening
              accumulator(
                opening,
                closing,
                enclosing,
                [first, ..already_processed],
                option.None,
                [],
                rest,
              )
            }
            option.Some(dude) ->
              // *
              // we do a pairing
              // *
              accumulator(
                opening,
                closing,
                enclosing,
                [
                  V(
                    infra.get_blame(dude) |> infra.append_blame_comment("paired with " <> ins(infra.get_blame(first))),
                    enclosing,
                    [],
                    after_last_opening |> list.reverse,
                  ),
                  ..already_processed
                ],
                option.None,
                [],
                rest,
              )
          }
        True, True ->
          case last_opening {
            option.None -> {
              // *
              // we make the V-node the new value of last_opening
              // *
              let assert [] = after_last_opening
              accumulator(
                opening,
                closing,
                enclosing,
                already_processed,
                option.Some(first),
                [],
                rest,
              )
            }
            option.Some(dude) ->
              // *
              // we do a pairing
              // *
              accumulator(
                opening,
                closing,
                enclosing,
                [
                  V(
                    infra.get_blame(dude) |> infra.append_blame_comment("paired with " <> ins(infra.get_blame(first))),
                    enclosing,
                    [],
                    after_last_opening |> list.reverse,
                  ),
                  ..already_processed
                ],
                option.None,
                [],
                rest,
              )
          }
      }
  }
}

fn nodemap(
  node: VXML,
  inner: InnerParam,
) -> VXML {
  let #(opening, closing, enclosing) = inner
  case node {
    T(_, _) -> node
    V(blame, tag, attrs, children) -> {
      let new_children =
        accumulator(
          opening,
          closing,
          enclosing,
          [],
          option.None,
          [],
          children,
        )
      V(blame, tag, attrs, new_children)
    }
  }
}

fn nodemap_factory(inner: InnerParam) -> n2t.OneToOneNoErrorNodeMap {
  nodemap(_, inner)
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  nodemap_factory(inner)
  |> n2t.one_to_one_no_error_nodemap_2_desugarer_transform()
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String,    String,     String)
//  ↖          ↖           ↖
//  opening    closing     enclosing
//  tag        tag         tag
type InnerParam = Param

const name = "pair"
const constructor = pair

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
/// pairs opening and closing bookend tags by
/// wrapping content between them in an enclosing
/// tag
pub fn pair(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.Some(ins(param)),
    option.None,
    "
/// pairs opening and closing bookend tags by
/// wrapping content between them in an enclosing
/// tag
    ",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(name, assertive_tests_data(), constructor)
}