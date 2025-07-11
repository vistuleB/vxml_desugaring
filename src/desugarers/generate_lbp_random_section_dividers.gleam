import gleam/pair
import gleam/float
import gleam/string.{inspect as ins}
import gleam/result
import gleam/list
import gleam/int
import gleam/option.{type Option, Some, None}
import infrastructure.{type Desugarer, Desugarer, type DesugarerTransform, type DesugaringError} as infra
import vxml.{type VXML, V, BlamedAttribute}


type RNG = fn(Option(Int), Float, Float) -> #(Int, Int) 

const m = 2147483648
const a = 1103515245
const c = 12345


fn rng_factory(seed: Int) -> RNG {
  fn(prev_state, min, max) {

    let prev_state = case prev_state {
      Some(prev_state) -> prev_state
      None -> seed
    }
    let new_state = {a * prev_state + c} % m

    let random_fraction = 
      int.to_float(new_state)
      |> float.divide(int.to_float(m - 1))
      |> result.unwrap(0.0)

    #(
      float.round(min +. random_fraction *. {max -. min}),
      new_state
    )
  }
}

fn map_children(children: List(VXML), generator: RNG, inner: InnerParam) -> List(VXML) {

  children
  |> list.map_fold(None, fn(acc, child) {
    case child {
      V(_, "Section", _, _) -> {
        let max = int.to_float(inner)
        let #(generated_number, generator_state) = generator(acc, 1.0, max)

        #(
          Some(generator_state),
          [
            child,
            V(
              infra.blame_us("generate_lbp_random_section_dividers"),
              "SectionDivider",
              [
                BlamedAttribute(
                  infra.blame_us("generate_lbp_random_section_dividers"),
                  "src",
                  "images/section_divider_" <> ins(generated_number) <> ".svg",
                ),
              ],
            []),
          ]
        )
      }
      _ -> #(acc, [child])
    }
  })
  |> pair.second
  |> list.flatten
}

fn map_chapter(child: VXML, index: Int, inner: InnerParam) -> Result(VXML, DesugaringError) {
  let rng = rng_factory(index)

  case child {
    V(_, tag, _, children) if tag == "Chapter" || tag == "Bootcamp" -> 
      Ok(V(..child, children: map_children(children, rng, inner)))
    _ -> Ok(child)
  }
}

fn at_root(root: VXML, inner: InnerParam) -> Result(VXML, DesugaringError) {
  let assert V(_, _, _, children) = root
  use children <- result.try(
    children
    |> list.index_map(fn(child, index) { map_chapter(child, index, inner) })
    |> result.all
  )
  Ok(infra.replace_children_with(root, children))
}

fn transform_factory(inner: InnerParam) -> DesugarerTransform {
  at_root(_, inner)
}

fn param_to_inner_param(param: Param) -> Result(InnerParam, DesugaringError) {
  Ok(param)
}

type Param = Int // number of section dividers to choose from
type InnerParam = Int 

const name = "generate_lbp_random_section_dividers"
const constructor = generate_lbp_random_section_dividers

// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
// 🏖️🏖️ Desugarer 🏖️🏖️
// 🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️🏖️
//------------------------------------------------53
pub fn generate_lbp_random_section_dividers(param: Param) -> Desugarer {
  Desugarer(
    name,
    option.None,
    "Insert SectionDivider after each Section with seeded random image each time. Seed is based on chapter index",
    case param_to_inner_param(param) {
      Error(error) -> fn(_) { Error(error) }
      Ok(inner) -> transform_factory(inner)
    },
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
