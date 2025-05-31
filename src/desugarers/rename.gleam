import gleam/option
import infrastructure.{
  type Desugarer, type DesugaringError, type Pipe, DesugarerDescription,
  DesugaringError, Pipe,
} as infra
import vxml.{type VXML, T, V}

fn transform(vxml: VXML, param: InnerParam) -> Result(VXML, DesugaringError) {
  case vxml {
    T(_, _) -> Ok(vxml)
    V(blame, tag, attrs, children) -> {
      let #(from, to) = param
      case from == tag {
        False -> Ok(vxml)
        True -> Ok(V(blame, to, attrs, children))
      }
    }
  }
}

fn transform_factory(param: InnerParam) -> infra.NodeToNodeTransform {
  transform(_, param)
}

fn desugarer_factory(param: InnerParam) -> Desugarer {
  infra.node_to_node_desugarer_factory(transform_factory(param))
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  let #(_, to) = param
  case infra.valid_tag(to) {
    True -> Ok(param)
    False -> Error(DesugaringError(infra.no_blame, "invalid target tag name '" <> to <> "'"))
  }
}

type Param = #(String, String)
type InnerParam = Param

pub fn rename(param: Param) -> Pipe {
  Pipe(
    description: DesugarerDescription(
      "rename",
      option.None,
      "renames one tag"
    ),
    desugarer: case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(param) -> desugarer_factory(param)
    }
  )
}
