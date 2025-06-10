import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/yielder

pub type RookMove {
  RookMove(
    up: List(Int),
    up_reverse: List(Int),
    down: List(Int),
    down_reverse: List(Int),
    left: List(Int),
    left_reverse: List(Int),
    right: List(Int),
    right_reverse: List(Int),
  )
}

pub type BishopMove {
  BishopMove(
    up_left: List(Int),
    up_left_reverse: List(Int),
    down_left: List(Int),
    down_left_reverse: List(Int),
    up_right: List(Int),
    up_right_reverse: List(Int),
    down_right: List(Int),
    down_right_reverse: List(Int),
  )
}

pub type SlidingMoves {
  SlidingMoves(rook: RookMove, bishop: BishopMove)
}

pub type SlidingDictionary =
  Dict(Int, SlidingMoves)

pub fn generate_sliding_dict() {
  generate_sliding_moves_loop(0, dict.new())
}

fn generate_sliding_moves_loop(
  at: Int,
  dict: SlidingDictionary,
) -> SlidingDictionary {
  case at < 0 || at >= 64 {
    True -> dict
    False ->
      generate_sliding_move_at(at)
      |> dict.insert(dict, at, _)
  }
}

fn generate_sliding_move_at(at index: Int) -> SlidingMoves {
  let left =
    yielder.iterate(index, fn(i) { i - 1 })
    |> yielder.take_while(satisfying: fn(i) {
      int.bitwise_and(i, 0o7_0) == int.bitwise_and(index, 0o7_0)
    })
    |> yielder.to_list()

  let right =
    yielder.iterate(index, fn(i) { i + 1 })
    |> yielder.take_while(satisfying: fn(i) {
      int.bitwise_and(i, 0o7_0) == int.bitwise_and(index, 0o7_0)
    })
    |> yielder.to_list()

  let up =
    yielder.iterate(index, fn(i) { i + 8 })
    |> yielder.take_while(satisfying: fn(i) { i < 64 })
    |> yielder.to_list()

  let down =
    yielder.iterate(index, fn(i) { i - 8 })
    |> yielder.take_while(satisfying: fn(i) { i > 0 })
    |> yielder.to_list()

  let left_length = list.length(left)
  let right_length = list.length(right)
  let up_length = list.length(up)
  let down_length = list.length(down)

  let up_left =
    yielder.iterate(index, fn(i) { i + 8 - 1 })
    |> yielder.take(int.min(left_length, up_length))
    |> yielder.to_list()

  let up_right =
    yielder.iterate(index, fn(i) { i + 8 + 1 })
    |> yielder.take(int.min(right_length, up_length))
    |> yielder.to_list()

  let down_left =
    yielder.iterate(index, fn(i) { i - 8 - 1 })
    |> yielder.take(int.min(left_length, down_length))
    |> yielder.to_list()

  let down_right =
    yielder.iterate(index, fn(i) { i - 8 + 1 })
    |> yielder.take(int.min(right_length, down_length))
    |> yielder.to_list()

  SlidingMoves(
    rook: RookMove(
      up:,
      up_reverse: list.reverse(up),
      down:,
      down_reverse: list.reverse(down),
      left:,
      left_reverse: list.reverse(left),
      right:,
      right_reverse: list.reverse(right),
    ),
    bishop: BishopMove(
      up_left:,
      up_left_reverse: list.reverse(up_left),
      up_right:,
      up_right_reverse: list.reverse(up_right),
      down_left:,
      down_left_reverse: list.reverse(down_left),
      down_right:,
      down_right_reverse: list.reverse(down_right),
    ),
  )
}
