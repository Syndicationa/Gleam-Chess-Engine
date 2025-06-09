import chess_engine/internal/fen.{
  CastlingRightsError, EnPassantSquareError, HalfMoveCountNotNumber, InvalidFEN,
  MoveCountNotNumber,
}
import gleam/result

// This is the default FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

pub fn invalid_fen_test() {
  assert fen.create_board("not a fen string") == Error(InvalidFEN)
}

pub fn invalid_en_passant_test() {
  let board =
    fen.create_board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
  let invalid_board =
    fen.create_board(
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq d90 0 1",
    )

  assert result.is_ok(board)
    && invalid_board == Error(EnPassantSquareError("d90"))
}

pub fn invalid_castling_test() {
  let board =
    fen.create_board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
  let invalid_board =
    fen.create_board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQwq - 0 1")

  assert result.is_ok(board)
  assert invalid_board == Error(CastlingRightsError("KQwq"))
}

pub fn invalid_move_count_test() {
  let board =
    fen.create_board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  let invalid_board_half_move =
    fen.create_board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - ? 1")

  let invalid_board_full_move =
    fen.create_board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 |")

  assert result.is_ok(board)
  assert invalid_board_half_move == Error(HalfMoveCountNotNumber)
  assert invalid_board_full_move == Error(MoveCountNotNumber)
}
