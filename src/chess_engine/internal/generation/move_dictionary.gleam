import chess_engine/internal/board/bitboard
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
  RookMove(up: Int, down: Int, left: Int, right: Int)
}

///Like RookMove, BishopMove stores the squares a piece can move to in both forward and reverse order allowing for easy generation of the bitmask
pub type BishopMove {
  BishopMove(up_left: Int, down_left: Int, up_right: Int, down_right: Int)
}

///King and Knights provide the indeces of every valid square they can move to
pub type Moves {
  Moves(rook: RookMove, bishop: BishopMove, king: Int, knight: Int)
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

fn generate_moves_from_list(move_list: List(#(Int, Int)), location: Int) -> Int {
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
  |> list.fold(0, bitboard.add_to_bitboard)
}

fn generate_moves_at(at index: Int) -> Moves {
  let left =
    yielder.iterate(index - 1, fn(i) { i - 1 })
    |> yielder.take_while(satisfying: fn(i) {
      int.bitwise_and(i, 0o7_0) == int.bitwise_and(index, 0o7_0)
    })

  let right =
    yielder.iterate(index + 1, fn(i) { i + 1 })
    |> yielder.take_while(satisfying: fn(i) {
      int.bitwise_and(i, 0o7_0) == int.bitwise_and(index, 0o7_0)
    })

  let up =
    yielder.iterate(index + 8, fn(i) { i + 8 })
    |> yielder.take_while(satisfying: fn(i) { i < 64 })

  let down =
    yielder.iterate(index - 8, fn(i) { i - 8 })
    |> yielder.take_while(satisfying: fn(i) { i >= 0 })

  let left_length = yielder.length(left)
  let right_length = yielder.length(right)
  let up_length = yielder.length(up)
  let down_length = yielder.length(down)

  let up_left =
    yielder.iterate(index + 8 - 1, fn(i) { i + 8 - 1 })
    |> yielder.take(int.min(left_length, up_length))

  let up_right =
    yielder.iterate(index + 8 + 1, fn(i) { i + 8 + 1 })
    |> yielder.take(int.min(right_length, up_length))

  let down_left =
    yielder.iterate(index - 8 - 1, fn(i) { i - 8 - 1 })
    |> yielder.take(int.min(left_length, down_length))

  let down_right =
    yielder.iterate(index - 8 + 1, fn(i) { i - 8 + 1 })
    |> yielder.take(int.min(right_length, down_length))

  Moves(
    rook: RookMove(
      up: yielder.fold(up, 0, bitboard.add_to_bitboard),
      down: yielder.fold(down, 0, bitboard.add_to_bitboard),
      left: yielder.fold(left, 0, bitboard.add_to_bitboard),
      right: yielder.fold(right, 0, bitboard.add_to_bitboard),
    ),
    bishop: BishopMove(
      up_left: yielder.fold(up_left, 0, bitboard.add_to_bitboard),
      up_right: yielder.fold(up_right, 0, bitboard.add_to_bitboard),
      down_left: yielder.fold(down_left, 0, bitboard.add_to_bitboard),
      down_right: yielder.fold(down_right, 0, bitboard.add_to_bitboard),
    ),
    king: generate_moves_from_list(king_moves, index),
    knight: generate_moves_from_list(knight_moves, index),
  )
}
