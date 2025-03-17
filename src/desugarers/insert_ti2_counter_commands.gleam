import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/string
import infrastructure.{ type Desugarer, type DesugaringError, type Pipe, Pipe, DesugarerDescription, DesugaringError } as infra
import vxml_parser.{type VXML, T, V, BlamedContent, type BlamedContent}

fn updated_node(
  vxml: VXML,
  prefix: Option(BlamedContent),
  cc: #(BlamedContent, Option(String)), // string is for the wrapper tag
  rest: BlamedContent,
  ) -> VXML {
  let assert V(blame, tag, attributes, children) = vxml
  let assert [T(t_blame, blamed_contents), ..] = children
 
  let prefix = infra.on_none_on_some(
    prefix,
    [],
    fn(p) { [p] }
  )

  let #(counter_command, wrapper) = cc

  let new_children = infra.on_none_on_some(
    wrapper,
    [
      T(t_blame, list.flatten([prefix, [counter_command], [rest], list.drop(blamed_contents, 1)])),
      ..list.drop(children, 1),
    ],
    fn(wrapper) {
      let wrapper_node = V(t_blame, wrapper, [], [T(t_blame, [counter_command])])
      [
        T(t_blame, prefix),
        wrapper_node,
        T(t_blame, [rest, ..list.drop(blamed_contents, 1)]),
        ..list.drop(children, 1),
      ]
    }
  )

  V(blame, tag, attributes, new_children)
}

fn param_transform(
  vxml: VXML,
  extra: Extra,
) -> Result(VXML, DesugaringError) {
  let #(counter_command, #(key, value), prefixes, wrapper) = extra

  case vxml {
    T(_, _) -> Ok(vxml)
    V(_, _, _, children) -> {
      use <- infra.on_false_on_true(
        over: infra.has_attribute(vxml, key, value),
        with_on_false: Ok(vxml)
      )


        // get first text node
      case children {
        [T(t_blame, blamed_contents), ..] -> {
          let assert [first_line, ..] = blamed_contents
          let found_prefix = list.find(prefixes, fn (prefix) {
            string.starts_with(first_line.content, prefix)
          })

              case found_prefix, list.is_empty(prefixes) {
                Ok(found_prefix), _ ->  {
                  let blamed_cc = BlamedContent(first_line.blame, counter_command)
                  let blamed_prefix = BlamedContent(first_line.blame, found_prefix)
                  let rest = BlamedContent(first_line.blame, string.length(found_prefix) |> string.drop_start(first_line.content, _))

              updated_node(vxml, Some(blamed_prefix), #(blamed_cc, wrapper), rest) |> Ok
            }
            Error(_), True -> {
              let blamed_cc = BlamedContent(t_blame, counter_command)
              updated_node(vxml, None, #(blamed_cc, wrapper), first_line) |> Ok
            }
            Error(_), False -> Ok(vxml)
          }
        }
        _ -> Ok(vxml)
      }
    }
  }
}

fn desugarer_factory(
  extra: Extra,
) -> Desugarer {
  infra.node_to_node_desugarer_factory(param_transform(_, extra))
}

type Extra = #(String, #(String, String), List(String), Option(String))

/// # Extra:
/// 
///  - Counter command to insert . ex: "::++Counter"
///  - key-value pair of node to insert counter command
///  - list of strings before counter command
///  - A wrapper tag to wrap the counter command string
pub fn insert_ti2_counter_commands(extra: Extra) -> Pipe {
  Pipe(
    description: DesugarerDescription("insert_ti2_counter_commands", option.Some(string.inspect(extra)), "..."),
    desugarer: desugarer_factory(extra),
  )
}
