import argv
import chess_engine/internal/board/fen.{type CreationError}
import chess_engine/internal/generation/move_dictionary
import chess_engine/internal/generation/move_generation
import chess_engine/internal/perft
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp

pub const chess_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

pub fn play_game(from: String) -> Result(Nil, CreationError) {
  use board <- result.try(fen.create_board(from))

  let table = move_dictionary.generate_move_dict()

  let now = timestamp.system_time()
  let moves = move_generation.get_all_moves(table, board)
  let later = timestamp.system_time()

  timestamp.difference(now, later)
  |> duration.to_seconds_and_nanoseconds
  |> echo

  list.length(moves)
  |> echo

  Ok(Nil)
}

pub type PerftError {
  FENError(CreationError)
  DepthError(String)
}

pub fn perform_perft(fen: String, depth_str: String) -> Result(Nil, PerftError) {
  use board <- result.try(
    fen.create_board(fen) |> result.map_error(fn(c) { FENError(c) }),
  )
  use depth <- result.try(
    int.parse(depth_str) |> result.replace_error(DepthError(depth_str)),
  )

  perft.perft(board, depth)
  |> int.to_string()
  |> string.append(to: "Perft found: ", suffix: _)
  |> string.append(" at depth " <> depth_str)
  |> io.println()

  Ok(Nil)
}

pub fn main() -> Nil {
  case argv.load().arguments {
    //This will be the standard mode
    [] -> {
      play_game(chess_fen)
      Nil
    }

    //Start game from FEN string
    ["from", fen] -> {
      play_game(fen)
      Nil
    }
    //Perform perft at depth from starting position
    ["perft", depth] ->
      perform_perft(chess_fen, depth)
      |> result.map_error(fn(e) {
        echo e
        Nil
      })
      |> result.unwrap_both()

    //Perform perft at depth from given position
    ["perft", fen, depth] ->
      perform_perft(fen, depth)
      |> result.map_error(fn(e) {
        echo e
        Nil
      })
      |> result.unwrap_both()
    _ -> io.println("This is not a valid run mode!")
  }

  // todo
  Nil
}
