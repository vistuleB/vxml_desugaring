// Un used 

import gleam/list
import gleam/string
import simplifile

fn handle_file(path: String, output: String, indent: Int) {
  let assert Ok(content) = simplifile.read(path)
  let indent_multiplication = case string.contains(path, "__parent") {
    True -> indent * 4
    False -> { indent + 1 } * 4
  }

  let indent = list.repeat(" ", indent_multiplication) |> string.join("")
  let indented =
    content
    |> string.split("\n")
    |> list.map(fn(x) { indent <> x })
    |> string.join("\n")

  output <> indented <> "\n"
}

fn handle_dir(path: String, output: String, indent: Int) {
  let assert Ok(dir) = simplifile.read_directory(path)
  let dir = list.sort(dir, fn(a, b) { string.compare(a, b) })
  case dir {
    [] -> ""
    [first, ..rest] -> {
      let paths =
        [first, ..rest]
        |> list.map(fn(x) { path <> "/" <> x })
      let assert Ok(res) = merge_content(paths, output, indent)
      res
    }
  }
}

pub fn merge_content(
  paths: List(String),
  output: String,
  indent: Int,
) -> Result(String, simplifile.FileError) {
  case paths {
    [] -> Ok(output)
    [first, ..rest] -> {
      let assert Ok(is_file) = simplifile.is_file(first)
      let name = case string.split(first, "/") |> list.reverse() {
        [] -> ""
        [name, ..] -> name
      }
      let output = case is_file, string.starts_with(name, "#") {
        True, False -> handle_file(first, output, indent)
        False, False -> handle_dir(first, output, indent + 1)
        _, _ -> output
      }
      merge_content(rest, output, indent)
    }
  }
}
