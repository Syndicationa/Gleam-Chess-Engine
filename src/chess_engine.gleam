import argv
import chess_engine/internal/board/fen.{type CreationError}
import chess_engine/internal/perft
import chess_engine/play
import chess_engine/speed_test
import gleam/int
import gleam/io
import gleam/result
import gleam/string

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
      let _ = play.game(chess_fen)

      Nil
    }

    //Start game from FEN string
    ["from", fen] -> {
      let _ = play.game(fen)

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

    //Tests the movement application speed
    ["test", "movement"] ->
      speed_test.movement_test(chess_fen)
      |> result.unwrap(Nil)

    //Tests the movement generation speed
    ["test", "generation"] ->
      speed_test.move_generation_test(
        "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
      )
      |> result.unwrap(Nil)

    //Tests the board evaluation speed
    ["test", "evaluation"] ->
      speed_test.move_generation_test(chess_fen)
      |> result.unwrap(Nil)

    _ -> io.println("This is not a valid run mode!")
  }
}
