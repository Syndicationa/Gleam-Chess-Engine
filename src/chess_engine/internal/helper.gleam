pub fn ternary(boolean: Bool, if_true t: a, if_false f: a) -> a {
  case boolean {
    True -> t
    False -> f
  }
}
