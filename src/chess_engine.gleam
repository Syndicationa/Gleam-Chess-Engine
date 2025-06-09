import argv
import chess_engine/internal/fen.{type CreationError}
import gleam/io
import gleam/result

pub const chess_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

pub fn play_game(from: String) -> Result(Nil, CreationError) {
  use _board <- result.try(fen.create_board(from))

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
    ["perft", _depth] -> todo

    //Perform perft at depth from given position
    ["perft", _fen, _depth] -> todo
    _ -> io.println("This is not a valid run mode!")
  }

  todo
}
