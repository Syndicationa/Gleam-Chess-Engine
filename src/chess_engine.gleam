import argv
import chess_engine/internal/board/board
import chess_engine/internal/board/fen.{type CreationError}
import chess_engine/internal/board/print
import chess_engine/internal/generation/move_dictionary
import chess_engine/internal/generation/move_generation
import chess_engine/internal/perft
import chess_engine/play
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp

pub const chess_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

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
      play.game(chess_fen)

      Nil
    }

    //Start game from FEN string
    ["from", fen] -> {
      play.game(fen)

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
}
