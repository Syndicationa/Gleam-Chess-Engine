import chess_engine/internal/board/board.{Knight, Pawn, Rook}
import chess_engine/internal/board/fen
import chess_engine/internal/board/move.{type Move, Move, Normal}
import gleam/option.{None, Some}

const reti: Move = Move(
  piece: Knight,
  source: 0o0_6,
  target: 0o2_5,
  data: Normal,
)

const kings_pawn: Move = Move(
  piece: Pawn,
  source: 0o1_4,
  target: 0o3_4,
  data: Normal,
)

const black_null_move: Move = Move(
  piece: Rook,
  source: 0o7_7,
  target: 0o7_7,
  data: Normal,
)

pub fn move_test() {
  let assert Ok(board) = fen.create_board(fen.default_fen)
  let reti_then_pawn =
    board
    |> move.move(reti)
    |> move.move(black_null_move)
    |> move.move(kings_pawn)

  let pawn_then_reti =
    board
    |> move.move(kings_pawn)
    |> move.move(black_null_move)
    |> move.move(reti)

  assert reti_then_pawn.pieces != board.pieces
  assert pawn_then_reti.pieces == reti_then_pawn.pieces
}

pub fn en_passant_test() {
  let assert Ok(board) = fen.create_board(fen.default_fen)
  let pawn_two_squares =
    board
    |> move.move(kings_pawn)

  let next_move =
    pawn_two_squares
    |> move.move(black_null_move)

  let en_passant_square = Some(0o2_4)

  assert pawn_two_squares.en_passant_square == en_passant_square
  assert next_move.en_passant_square == None
}
