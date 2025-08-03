import vxml.{type VXML, V, T}
// import infrastructure as infra
// import gleam/int
// import gleam/list

// fn take_from_v_tag_and_attributes(
//   v: VXML,
//   special_tag: String,
//   gas_remaining: Int,
// ) -> #(List(VXML), Int) {
//   let assert V(blame, tag, attrs, _) = v
//   let gas_remaining = case tag == special_tag {

//   }
// }

// fn take_from_t(
//   t: VXML,
//   gas_remaining: Int,
// ) -> #(List(VXML), Int) {
//   let assert T(blame, lines) = t
//   use <- infra.on_false_on_true(
//     gas_remaining > 1,
//     #([], 0),
//   )
//   let lines_2_take = int.min(
//     gas_remaining - 1,
//     list.length(lines),
//   )
//   #(
//     [T(blame, list.take(lines, lines_2_take))],
//     gas_remaining - 1 - lines_2_take,
//   )
// }

// fn go_go(
//   vxml: VXML,
//   special_tag: String,
//   gas_remaining: Int,
//   max_tank: Int,
// ) -> #(List(VXML), Int) {
//   case vxml {
//     T(blame, lines) -> {
//       case gas_remaining > 1 {
//         True -> #([T(blame, list.take(lines, gas_remaining - 1))], gas_remaining - 1 - list.length(lines))
//         False -> #([], 0)
//       }
//     }
//     V(_, tag, _, _) -> {
//       let gas_remaining = case tag == special_tag {
//         True -> max_tank
//         False -> gas_remaining
//       }

//     }
//   }
// }

// pub fn within_x_lines_below_tag(
//   root: VXML,
//   tag: String,
//   within: Int,
// ) -> List(VXML) {

// }