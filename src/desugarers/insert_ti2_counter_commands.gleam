import gleam/list
import gleam/option.{type Option}
import gleam/string.{inspect as ins}
import infrastructure.{type Desugarer, type DesugaringError, type Pipe, DesugarerDescription, Pipe} as infra
import vxml.{type BlamedContent, type VXML, BlamedContent, T, V}

fn updated_node(
  vxml: VXML,
  prefix: Option(BlamedContent),
  cc: #(BlamedContent, Option(String)),
  // string is for the wrapper tag
  rest: BlamedContent,
) -> VXML {
  let assert V(blame, tag, attributes, children) = vxml
  let assert [T(t_blame, blamed_contents), ..] = children

  let prefix = infra.on_none_on_some(prefix, [], fn(p) { [p] })

  let #(counter_command, wrapper) = cc

  let new_children =
    infra.on_none_on_some(
      wrapper,
      [
        T(
          t_blame,
          list.flatten([
            prefix,
            [counter_command],
            [rest],
            list.drop(blamed_contents, 1),
          ]),
        ),
        ..list.drop(children, 1)
      ],
      fn(wrapper) {
        let wrapper_node =
          V(t_blame, wrapper, [], [T(t_blame, [counter_command])])
        [
          T(t_blame, prefix),
          wrapper_node,
          T(t_blame, [rest, ..list.drop(blamed_contents, 1)]),
          ..list.drop(children, 1)
        ]
      },
    )

  V(blame, tag, attributes, new_children)
}

fn transform(
  vxml: VXML,
  inner: InnerParam,
) -> Result(VXML, DesugaringError) {
  let #(counter_command, #(key, value), prefixes, wrapper) = inner

  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, _, _, children) -> {
      use <- infra.on_false_on_true(
        over: infra.v_has_key_value(vxml, key, value),
        with_on_false: Ok(vxml),
      )

      // get first text node
      case children {
        [T(t_blame, blamed_contents), ..] -> {
          let assert [first_line, ..] = blamed_contents
          let found_prefix =
            list.find(prefixes, fn(prefix) {
              string.starts_with(first_line.content, prefix)
            })

          case found_prefix, list.is_empty(prefixes) {
            Ok(found_prefix), _ -> {
              let blamed_cc = BlamedContent(first_line.blame, counter_command)
              let blamed_prefix = BlamedContent(first_line.blame, found_prefix)
              let rest =
                BlamedContent(
                  first_line.blame,
                  string.length(found_prefix)
                    |> string.drop_start(first_line.content, _),
                )

              updated_node(
                vxml,
                option.Some(blamed_prefix),
                #(blamed_cc, wrapper),
                rest,
              )
              |> Ok
            }
            Error(_), True -> {
              let blamed_cc = BlamedContent(t_blame, counter_command)
              updated_node(vxml, option.None, #(blamed_cc, wrapper), first_line) |> Ok
            }
            Error(_), False -> Ok(vxml)
          }
        }
        _ -> Ok(vxml)
      }
    }
  }
}

fn transform_factory(inner: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, inner)
}

fn desugarer_factory(inner: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(inner))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param =
  #(String, #(String, String), List(String), Option(String))
//  ↖       ↖                  ↖            ↖
//  counter key-value pair     list of      wrapper
//  command to insert         strings      tag to
//  to      counter command   before       wrap the
//  insert                    counter      counter
//                           command      command

type InnerParam = Param

pub const desugarer_name = "insert_ti2_counter_commands"
pub const desugarer_pipe = insert_ti2_counter_commands

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️ pipe 🏖️🏖️🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------

/// inserts TI2 counter commands into text nodes of specified elements
/// # Param:
///  - Counter command to insert . ex: "::++Counter"
///  - key-value pair of node to insert counter command
///  - list of strings before counter command
///  - A wrapper tag to wrap the counter command string
pub fn insert_ti2_counter_commands(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      desugarer_name: desugarer_name,
      stringified_param: option.Some(ins(param)),
      general_description: "
/// inserts TI2 counter commands into text nodes of specified elements
/// # Param:
///  - Counter command to insert . ex: \"::++Counter\"
///  - key-value pair of node to insert counter command
///  - list of strings before counter command
///  - A wrapper tag to wrap the counter command string
      ",
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> desugarer_factory(inner)
    }
  )
}

// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
// 🌊🌊🌊 tests 🌊🌊🌊🌊
// 🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
fn assertive_tests_data() -> List(infra.AssertiveTestData(Param)) {
  []
}

pub fn assertive_tests() {
  infra.assertive_tests_from_data(desugarer_name, assertive_tests_data(), desugarer_pipe)
}