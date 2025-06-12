import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/yielder

const knight_moves = [
  #(2, 1),
  #(1, 2),
  #(-2, 1),
  #(-1, 2),
  #(2, -1),
  #(1, -2),
  #(-2, -1),
  #(-1, -2),
]

const king_moves = [
  #(1, 0),
  #(0, 1),
  #(0, -1),
  #(-1, 0),
  #(1, 1),
  #(-1, 1),
  #(1, -1),
  #(-1, -1),
]

///Like BishopMove, RookMove stores the squares a piece can move to in both forward and reverse order allowing for easy generation of the bitmask
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

///Like RookMove, BishopMove stores the squares a piece can move to in both forward and reverse order allowing for easy generation of the bitmask
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

///King and Knights provide the indeces of every valid square they can move to
pub type Moves {
  Moves(rook: RookMove, bishop: BishopMove, king: List(Int), knight: List(Int))
}

pub type MoveDictionary =
  Dict(Int, Moves)

pub fn generate_move_dict() {
  generate_moves_loop(0, dict.new())
}

fn generate_moves_loop(at: Int, dictionary: MoveDictionary) -> MoveDictionary {
  case at >= 64 {
    True -> dictionary
    False ->
      generate_moves_at(at)
      |> dict.insert(dictionary, at, _)
      |> generate_moves_loop(at + 1, _)
  }
}

fn generate_moves_from_list(
  move_list: List(#(Int, Int)),
  location: Int,
) -> List(Int) {
  move_list
  |> list.filter_map(fn(value) {
    let #(d_x, d_y) = value
    let x = int.bitwise_and(location, 0o0_7)
    let y = int.bitwise_shift_right(location, 3)

    case x + d_x, y + d_y {
      x, y if x < 0 || y < 0 || x >= 8 || y >= 8 -> Error(Nil)
      x, y -> int.bitwise_shift_left(y, 3) + x |> Ok
    }
  })
}

fn generate_moves_at(at index: Int) -> Moves {
  let left =
    yielder.iterate(index - 1, fn(i) { i - 1 })
    |> yielder.take_while(satisfying: fn(i) {
      int.bitwise_and(i, 0o7_0) == int.bitwise_and(index, 0o7_0)
    })
    |> yielder.to_list()

  let right =
    yielder.iterate(index + 1, fn(i) { i + 1 })
    |> yielder.take_while(satisfying: fn(i) {
      int.bitwise_and(i, 0o7_0) == int.bitwise_and(index, 0o7_0)
    })
    |> yielder.to_list()

  let up =
    yielder.iterate(index + 8, fn(i) { i + 8 })
    |> yielder.take_while(satisfying: fn(i) { i < 64 })
    |> yielder.to_list()

  let down =
    yielder.iterate(index - 8, fn(i) { i - 8 })
    |> yielder.take_while(satisfying: fn(i) { i >= 0 })
    |> yielder.to_list()

  let left_length = list.length(left)
  let right_length = list.length(right)
  let up_length = list.length(up)
  let down_length = list.length(down)

  let up_left =
    yielder.iterate(index + 8 - 1, fn(i) { i + 8 - 1 })
    |> yielder.take(int.min(left_length, up_length))
    |> yielder.to_list()

  let up_right =
    yielder.iterate(index + 8 + 1, fn(i) { i + 8 + 1 })
    |> yielder.take(int.min(right_length, up_length))
    |> yielder.to_list()

  let down_left =
    yielder.iterate(index - 8 - 1, fn(i) { i - 8 - 1 })
    |> yielder.take(int.min(left_length, down_length))
    |> yielder.to_list()

  let down_right =
    yielder.iterate(index - 8 + 1, fn(i) { i - 8 + 1 })
    |> yielder.take(int.min(right_length, down_length))
    |> yielder.to_list()

  Moves(
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
    king: generate_moves_from_list(king_moves, index),
    knight: generate_moves_from_list(knight_moves, index),
  )
}
