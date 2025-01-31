import gleam/pair
import gleam/list
import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type NodeToNodeTransform, type Pipe,
  DesugarerDescription,
} as infra
import vxml_parser.{type VXML, T, V}

fn param_transform(vxml: VXML, extra: Param) -> Result(VXML, DesugaringError) {
  case vxml {
    V(blame, tag, atts, children) -> {
      case list.find(extra, fn(pair) { pair |> pair.first == tag }) {
        Error(Nil) -> Ok(vxml)
        Ok(#(_, #(start_tag, end_tag))) -> {
          Ok(
            V(
              blame,
              tag,
              atts,
              [
                [V(blame, start_tag, [], [])],
                children,
                [V(blame, end_tag, [], [])],
              ] |> list.flatten
            )
          )
        }
      }
    }
    T(_, _) -> Ok(vxml)
  }
}

fn transform_factory(param: Param) -> NodeToNodeTransform {
  param_transform(_, param)
}

fn desugarer_factory(param: Param) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn build_param(extra: Extra) -> Param {
  extra
  |> list.map(
    fn (triple) {
      let #(a, b, c) = triple
      #(a, #(b, c))
    }
  )
}

type Param = List(#(String, #(String, String)))

type Extra = List(#(String, String, String))

pub fn insert_first_and_last_child_tags(extra: Extra) -> Pipe {
  #(
    DesugarerDescription("insert_first_and_last_child_tags", option.None, "..."),
    desugarer_factory(extra |> build_param),
  )
}
