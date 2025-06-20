import chess_engine/internal/board/board.{Rook}
import chess_engine/internal/board/fen
import chess_engine/internal/board/move.{type Move, Move, Normal}
import chess_engine/internal/evaluation/evaluate
import chess_engine/internal/generation/move_dictionary
import chess_engine/internal/generation/move_generation
import gleam/int
import gleam/io
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp

const white_null_move: Move = Move(
  piece: Rook,
  source: 0o0_7,
  target: 0o0_7,
  data: Normal,
)

const black_null_move: Move = Move(
  piece: Rook,
  source: 0o7_7,
  target: 0o7_7,
  data: Normal,
)

pub fn movement_test(fen: String) {
  use board <- result.try(fen.create_board(fen))

  let ten_thousand_moves =
    list.range(0, 9999)
    |> list.map(fn(x) {
      case int.bitwise_and(x, 1) {
        0 -> white_null_move
        1 -> black_null_move
        _ -> white_null_move
      }
    })

  let start_time = timestamp.system_time()
  list.fold(ten_thousand_moves, board, move.move)
  let now = timestamp.system_time()

  timestamp.difference(start_time, now)
  |> duration.to_seconds_and_nanoseconds()
  |> pair.first
  |> int.to_string()
  |> string.append("It took: ", _)
  |> string.append("s")
  |> io.println()

  Ok(Nil)
}

pub fn move_generation_test(fen: String) {
  use board <- result.try(fen.create_board(fen))
  let dictionary = move_dictionary.generate_move_dict()

  let hundred_thousand_items = list.range(0, 99_999)

  let start_time = timestamp.system_time()
  list.each(hundred_thousand_items, fn(_) {
    move_generation.get_all_moves(dictionary, board)
  })
  let now = timestamp.system_time()

  timestamp.difference(start_time, now)
  |> duration.to_seconds_and_nanoseconds()
  |> pair.map_first(int.multiply(_, 1000))
  |> pair.map_second(fn(x) { x / 1_000_000 })
  |> fn(v) { v.0 + v.1 }
  |> int.to_string()
  |> string.append("It took: ", _)
  |> string.append("ms")
  |> io.println()

  Ok(Nil)
}

pub fn board_evaluator_test(fen: String) {
  use board <- result.try(fen.create_board(fen))
  let dictionary = move_dictionary.generate_move_dict()

  let hundred_thousand_items = list.range(0, 99_999)

  let start_time = timestamp.system_time()
  list.each(hundred_thousand_items, fn(_) {
    evaluate.evaluate(dictionary, board)
  })
  let now = timestamp.system_time()

  timestamp.difference(start_time, now)
  |> duration.to_seconds_and_nanoseconds()
  |> pair.map_first(int.multiply(_, 1000))
  |> pair.map_second(fn(x) { x / 1_000_000 })
  |> fn(v) { v.0 + v.1 }
  |> int.to_string()
  |> string.append("It took: ", _)
  |> string.append("ms")
  |> io.println()

  Ok(Nil)
}
