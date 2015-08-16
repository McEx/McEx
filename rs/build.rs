extern crate gcc;

fn main() {
    gcc::compile_library("libopensimplex.a", &["src/opensimplex.c"]);
}
