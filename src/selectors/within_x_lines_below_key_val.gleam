import vxml.{type VXML, V, T}
import infrastructure as infra
import gleam/int
import gleam/list
import gleam/option.{type Option, Some, None}

fn take_from_v_tag_and_attributes(
  v: VXML,
  initial_gas_remaining: Int,
  inner: Inner,
) -> #(Bool, Option(VXML), Int) {
  let assert V(blame, tag, attrs, _) = v
  let #(saved, attrs, gas_remaining) =
    list.fold(
      attrs,
      #(False, [], int.max(initial_gas_remaining - 1, 0)),
      fn (acc, attr) {
        let #(saved, attrs, gas_remaining) = acc
        let #(saved, gas_remaining) = case attr.key == inner.0 && attr.value == inner.1 {
          True -> #(True, inner.2)
          False -> #(saved, gas_remaining)
        }
        let attrs = case gas_remaining > 0 {
          True -> [attr, ..attrs]
          False -> attrs
        }
        #(saved, attrs, int.max(0, gas_remaining - 1))
      }
    )
  case list.is_empty(attrs) && initial_gas_remaining <= 0 {
    True -> {
      let assert True = gas_remaining == 0
      #(False, None, 0)
    }
    False -> #(saved, Some(V(blame, tag, attrs |> list.reverse, [])), gas_remaining)
  }
}

fn take_from_t(
  t: VXML,
  gas_remaining: Int,
) -> #(Bool, Option(VXML), Int) {
  let assert T(blame, lines) = t
  use <- infra.on_true_on_false(
    gas_remaining <= 0,
    #(False, None, 0),
  )
  let lines_2_take = int.min(
    gas_remaining,
    list.length(lines),
  )
  #(
    False,
    Some(T(blame, list.take(lines, lines_2_take))),
    gas_remaining - lines_2_take,
  )
}

fn take_from_v(
  vxml: VXML,
  initial_gas_remaining: Int,
  inner: Inner,
) -> #(Bool, Option(VXML), Int) {
  let assert V(_, _, _, children) = vxml

  let #(saved, head, gas_remaining) = take_from_v_tag_and_attributes(vxml, initial_gas_remaining, inner)
  case gas_remaining > 0 || initial_gas_remaining > 0 {
    True -> {let assert Some(_) = head}
    False -> None
  }

  let #(saved, gas_remaining, children) =
    list.fold(
      children,
      #(saved, gas_remaining, []),
      fn(acc, child) {
        let #(prev_saved, prev_gas, prev_children) = acc
        let #(new_saved, guy, gas_remaining) = take_from_vxml(child, prev_gas, inner)
        case gas_remaining > 0 || prev_gas > 0 {
          True -> {let assert Some(_) = guy}
          False -> None
        }
        case guy {
          Some(guy) -> #(prev_saved || new_saved, gas_remaining, [guy, ..prev_children])
          None -> #(prev_saved || new_saved, gas_remaining, prev_children)
        }
      }
    )

  let children = children |> list.reverse

  case saved {
    False -> {
      case head {
        None -> #(False, head, gas_remaining)
        Some(guy) -> {
          let assert V(_, _, _, _) = guy
          #(False, Some(V(..guy, children: children)), gas_remaining)
        }
      }
    }
    True -> {
      case head {
        None -> #(True, Some(V(..vxml, attributes: [], children: children)), gas_remaining)
        Some(guy) -> {
          let assert V(_, _, _, _) = guy
          #(True, Some(V(..guy, children: children)), gas_remaining)
        }
      }
    }
  }
}

fn take_from_vxml(
  vxml: VXML,
  gas_remaining: Int,
  inner: Inner,
) -> #(Bool, Option(VXML), Int) {
  case vxml {
    T(_, _) -> take_from_t(vxml, gas_remaining)
    V(_, _, _, _) -> take_from_v(vxml, gas_remaining, inner)
  }
}

type Inner = #(String, String, Int)

pub fn within_x_lines_below_key_val(
  root: VXML,
  key: String,
  value: String,
  within: Int,
) -> List(VXML) {
  let inner = #(key, value, within)
  case take_from_vxml(root, 0, inner) {
    #(True, Some(guy), _) -> [guy]
    #(False, None, 0) -> []
    _ -> panic as "unexpected"
  }
}