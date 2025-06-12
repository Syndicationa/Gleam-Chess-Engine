import chess_engine/internal/board/bitboard
import chess_engine/internal/board/board.{
  type Board, type Piece, Black, Board, Both, King, KingSide, NoCastle, Pawn,
  QueenSide, White,
}
import gleam/int
import gleam/option.{None, Some}

pub type CastleDirection {
  CastleKingSide
  CastleQueenSide
}

pub type MoveType {
  Normal
  Capture(Piece)
  Castle(CastleDirection)
  EnPassant
  Promotion(Piece)
  PromotionCapture(promotion: Piece, capture: Piece)
}

pub type Move {
  Move(piece: Piece, source: Int, target: Int, data: MoveType)
}

pub fn move(board: Board, move: Move) -> Board {
  case move.data {
    Normal -> standard_move(board, move)
    Capture(piece) ->
      remove_captured(board, piece, move.target) |> standard_move(move)
    Castle(direction) ->
      castle(board, move.target, direction) |> standard_move(move)
    EnPassant -> remove_en_passanted(board) |> standard_move(move)
    Promotion(target_piece) ->
      standard_move(board, move) |> promote(move.target, target_piece)
    PromotionCapture(promotion: target_piece, capture: capture_target) ->
      remove_captured(board, capture_target, move.target)
      |> standard_move(move)
      |> promote(move.target, target_piece)
  }
  |> invalidate_castling(move)
  |> add_en_passant(move)
  |> half_move_add(move)
  |> next_player()
}

fn standard_move(board_data: Board, move: Move) -> Board {
  let board_data =
    board.get_player_bitboard(board_data)
    |> bitboard.remove_from_bitboard(move.source)
    |> bitboard.add_to_bitboard(move.target)
    |> board.set_player_bitboard(board_data, _)

  board.get_piece_bitboard(board_data, move.piece)
  |> bitboard.remove_from_bitboard(move.source)
  |> bitboard.add_to_bitboard(move.target)
  |> board.set_piece_bitboard(board_data, move.piece, _)
}

fn remove_captured(
  board_data: Board,
  captured_piece: Piece,
  target: Int,
) -> Board {
  let board_data =
    board.get_opponent_bitboard(board_data)
    |> bitboard.remove_from_bitboard(target)
    |> board.set_opponent_bitboard(board_data, _)

  board.get_piece_bitboard(board_data, captured_piece)
  |> bitboard.remove_from_bitboard(target)
  |> board.set_piece_bitboard(board_data, captured_piece, _)
}

fn castle(board_data: Board, target: Int, direction: CastleDirection) -> Board {
  let source = case direction {
    CastleKingSide -> target + 1
    CastleQueenSide -> target - 2
  }

  let target = case direction {
    CastleKingSide -> target - 1
    CastleQueenSide -> target + 1
  }

  let new_move: Move = Move(piece: board.Rook, source:, target:, data: Normal)
  standard_move(board_data, new_move)
}

fn remove_en_passanted(board_data: Board) -> Board {
  case board_data.en_passant_square {
    None -> board_data
    Some(square) -> {
      let board_data =
        board.get_opponent_bitboard(board_data)
        |> bitboard.remove_from_bitboard(square + 8)
        |> bitboard.remove_from_bitboard(square - 8)
        |> board.set_opponent_bitboard(board_data, _)

      board.get_piece_bitboard(board_data, board.Pawn)
      |> bitboard.remove_from_bitboard(square + 8)
      |> bitboard.remove_from_bitboard(square - 8)
      |> board.set_piece_bitboard(board_data, board.Pawn, _)
    }
  }
}

fn promote(board_data: Board, location: Int, piece: Piece) {
  let board_data =
    board.get_piece_bitboard(board_data, Pawn)
    |> bitboard.remove_from_bitboard(location)
    |> board.set_piece_bitboard(board_data, Pawn, _)

  board.get_piece_bitboard(board_data, piece)
  |> bitboard.add_to_bitboard(location)
  |> board.set_piece_bitboard(board_data, piece, _)
}

fn invalidate_castling(board_data: Board, move: Move) {
  let king_move = move.piece == King
  let rook_move = case board_data.active_color, move.source {
    White, 0o0_0 -> Some(CastleQueenSide)
    White, 0o0_7 -> Some(CastleKingSide)
    Black, 0o7_0 -> Some(CastleQueenSide)
    Black, 0o7_7 -> Some(CastleKingSide)
    _, _ -> None
  }

  let rook_capture = case board_data.active_color, move.target {
    White, 0o7_0 -> Some(CastleQueenSide)
    White, 0o7_7 -> Some(CastleKingSide)
    Black, 0o0_0 -> Some(CastleQueenSide)
    Black, 0o0_7 -> Some(CastleKingSide)
    _, _ -> None
  }

  let player_castling = case
    board.get_player_castling(board_data),
    king_move,
    rook_move
  {
    NoCastle, _, _ -> NoCastle
    _, True, _ -> NoCastle
    KingSide, _, Some(CastleKingSide) -> NoCastle
    QueenSide, _, Some(CastleQueenSide) -> NoCastle
    Both, _, Some(CastleKingSide) -> QueenSide
    Both, _, Some(CastleQueenSide) -> KingSide
    state, _, _ -> state
  }

  let opponent_castling = case
    board.get_opponent_castling(board_data),
    rook_capture
  {
    NoCastle, _ -> NoCastle
    Both, Some(CastleKingSide) -> QueenSide
    Both, Some(CastleQueenSide) -> KingSide
    KingSide, Some(CastleKingSide) -> NoCastle
    QueenSide, Some(CastleQueenSide) -> NoCastle
    state, _ -> state
  }

  board.set_player_castling(board_data, player_castling)
  |> board.set_opponent_castling(opponent_castling)
}

fn add_en_passant(board_data: Board, move: Move) -> Board {
  case move.piece, int.absolute_value(move.source - move.target) {
    Pawn, 16 ->
      Board(
        ..board_data,
        en_passant_square: Some({ move.source + move.target } / 2),
      )
    _, _ -> Board(..board_data, en_passant_square: None)
  }
}

fn half_move_add(board_data: Board, move: Move) {
  case move.piece, move.data {
    Pawn, _ | _, Capture(_) -> Board(..board_data, half_move_count: 0)
    _, _ -> Board(..board_data, half_move_count: board_data.half_move_count + 1)
  }
}

fn next_player(board_data: Board) -> Board {
  case board_data.active_color {
    White -> Board(..board_data, active_color: Black)
    Black ->
      Board(
        ..board_data,
        active_color: White,
        move_count: board_data.move_count + 1,
      )
  }
}

fn position_to_string(locaiton: Int) {
  case int.bitwise_shift_right(locaiton, 3), int.bitwise_and(locaiton, 7) {
    rank, 0 -> "a" <> int.to_string(rank + 1)
    rank, 1 -> "b" <> int.to_string(rank + 1)
    rank, 2 -> "c" <> int.to_string(rank + 1)
    rank, 3 -> "d" <> int.to_string(rank + 1)
    rank, 4 -> "e" <> int.to_string(rank + 1)
    rank, 5 -> "f" <> int.to_string(rank + 1)
    rank, 6 -> "g" <> int.to_string(rank + 1)
    rank, 7 -> "h" <> int.to_string(rank + 1)
    _, _ -> "i" <> int.to_string(locaiton)
  }
}

pub fn to_string(move: Move) -> String {
  position_to_string(move.source) <> position_to_string(move.target)
}
