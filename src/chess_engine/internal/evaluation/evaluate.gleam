import chess_engine/internal/board/bitboard.{type BitBoard}
import chess_engine/internal/board/board.{
  type Board, type Color, type Piece, Bishop, King, Knight, Pawn, Queen, Rook,
}
import chess_engine/internal/board/move.{
  type Move, Capture, Castle, EnPassant, Promotion, PromotionCapture,
}
import chess_engine/internal/evaluation/positions
import chess_engine/internal/generation/move_dictionary.{type MoveDictionary}
import chess_engine/internal/generation/move_generation
import gleam/bool
import gleam/int
import gleam/list
import gleam/order.{Eq, Gt, Lt}

pub type BoardValue {
  Unrated
  Value(at: Int)
  Checkmate(in: Int)
  BookMove(count: Int)
  Stalemate
}

pub fn checkmate_to_score(ply) {
  case int.bitwise_and(ply, 1) {
    //Losing on even
    0 -> -1000 + ply
    1 -> 1000 - ply
    _ -> 0
  }
}

pub fn compare(first, second) {
  case first, second {
    Unrated, Unrated -> Eq
    Unrated, _ -> Lt
    Value(a), Value(b) -> int.compare(a, b)
    Value(a), Stalemate -> int.compare(a, 0)
    Stalemate, Stalemate -> Eq
    Checkmate(a), Checkmate(b) -> {
      let a = checkmate_to_score(a)
      let b = checkmate_to_score(b)

      int.compare(a, b)
    }
    _, Checkmate(count) ->
      int.bitwise_and(count, 1) |> int.multiply(2) |> int.compare(1)
    BookMove(_), BookMove(_) -> Eq
    BookMove(_), _ -> Gt
    a, b -> compare(b, a)
  }
}

pub fn max(a, b) {
  case compare(a, b) {
    Lt -> b
    Eq -> a
    Gt -> a
  }
}

pub fn add_ply(eval: BoardValue) {
  case eval {
    Unrated -> Unrated
    Value(x) -> Value(-x)
    Stalemate -> Stalemate
    Checkmate(x) -> Checkmate(x + 1)
    BookMove(x) -> BookMove(x)
  }
}

pub fn piece_value(piece: Piece) -> Int {
  case piece {
    Queen -> 900
    Rook -> 500
    Bishop -> 300
    Knight -> 300
    Pawn -> 100
    _ -> 00
  }
}

pub fn bit_count(source: BitBoard, running_count: Int) {
  use <- bool.guard(source == 0, running_count)

  let lsb = bitboard.isolate_lsb(source)
  bit_count(source - lsb, running_count + 1)
}

fn mg_side_value(board_data: Board, side: Color) {
  let side_board = board.get_color_bitboard(board_data, side)
  let king = int.bitwise_and(board_data.pieces.kings, side_board)
  let queens = int.bitwise_and(board_data.pieces.queens, side_board)
  let rooks = int.bitwise_and(board_data.pieces.rooks, side_board)
  let bishops = int.bitwise_and(board_data.pieces.bishops, side_board)
  let knights = int.bitwise_and(board_data.pieces.knights, side_board)
  let pawns = int.bitwise_and(board_data.pieces.pawns, side_board)

  let king_value =
    bitboard.fold_with(
      king,
      positions.mg_king_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(king, 0)
    * piece_value(King)

  let queen_value =
    bitboard.fold_with(
      queens,
      positions.mg_queen_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(queens, 0)
    * piece_value(Queen)

  let rook_value =
    bitboard.fold_with(
      rooks,
      positions.mg_rook_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(rooks, 0)
    * piece_value(Rook)

  let bishop_value =
    bitboard.fold_with(
      bishops,
      positions.mg_bishop_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(bishops, 0)
    * piece_value(Bishop)

  let knight_value =
    bitboard.fold_with(
      knights,
      positions.mg_knight_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(knights, 0)
    * piece_value(Knight)

  let pawn_value =
    bitboard.fold_with(
      pawns,
      positions.mg_pawn_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(pawns, 0)
    * piece_value(Pawn)

  king_value
  + queen_value
  + rook_value
  + bishop_value
  + knight_value
  + pawn_value
}

fn eg_side_value(board_data: Board, side: Color) {
  let side_board = board.get_color_bitboard(board_data, side)
  let king = int.bitwise_and(board_data.pieces.kings, side_board)
  let queens = int.bitwise_and(board_data.pieces.queens, side_board)
  let rooks = int.bitwise_and(board_data.pieces.rooks, side_board)
  let bishops = int.bitwise_and(board_data.pieces.bishops, side_board)
  let knights = int.bitwise_and(board_data.pieces.knights, side_board)
  let pawns = int.bitwise_and(board_data.pieces.pawns, side_board)

  let king_value =
    bitboard.fold_with(
      king,
      positions.eg_king_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(king, 0)
    * piece_value(King)

  let queen_value =
    bitboard.fold_with(
      queens,
      positions.eg_queen_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(queens, 0)
    * piece_value(Queen)

  let rook_value =
    bitboard.fold_with(
      rooks,
      positions.eg_rook_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(rooks, 0)
    * piece_value(Rook)

  let bishop_value =
    bitboard.fold_with(
      bishops,
      positions.eg_bishop_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(bishops, 0)
    * piece_value(Bishop)

  let knight_value =
    bitboard.fold_with(
      knights,
      positions.eg_knight_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(knights, 0)
    * piece_value(Knight)

  let pawn_value =
    bitboard.fold_with(
      pawns,
      positions.eg_pawn_table,
      0,
      0,
      fn(acc, _, square_value) { acc + square_value },
    )
    + bit_count(pawns, 0)
    * piece_value(Pawn)

  king_value
  + queen_value
  + rook_value
  + bishop_value
  + knight_value
  + pawn_value
}

fn side_value(board_data: Board, side: Color) {
  let is_end_game =
    board_data.pieces.queens == 0
    || bit_count(
      board_data.pieces.knights
        + board_data.pieces.bishops
        + board_data.pieces.queens,
      0,
    )
    <= 6

  case is_end_game {
    True -> eg_side_value(board_data, side)
    False -> mg_side_value(board_data, side)
  }
}

pub fn board_value(board_data: Board) -> Int {
  side_value(board_data, board_data.active_color)
  - side_value(board_data, board.opposite_color(board_data.active_color))
}

fn capture_value(capturing_piece: Piece, target: Piece) -> Int {
  3 * piece_value(target) - piece_value(capturing_piece)
}

fn promotion_value(promotion_target: Piece) -> Int {
  piece_value(promotion_target) - piece_value(Pawn)
}

pub fn prescore_move(move_data: Move) -> Int {
  case move_data.data {
    Capture(target) -> capture_value(move_data.piece, target)
    Promotion(target) -> promotion_value(target)
    PromotionCapture(promotion_target, capture_target) -> {
      capture_value(move_data.piece, capture_target)
      + promotion_value(promotion_target)
    }
    EnPassant -> 20
    Castle(_) -> 20
    _ -> 0
  }
}

fn evaluate_position(moves: List(Move), board_data: Board) {
  let prescores =
    list.fold(moves, 0, fn(score, move) { score + prescore_move(move) })
    / list.length(moves)

  board_value(board_data) * 100 + prescores
}

pub fn evaluate(move_dictionary: MoveDictionary, board_data: Board) {
  let moves = move_generation.get_all_moves(move_dictionary, board_data)
  let is_check = move_generation.in_check(move_dictionary, board_data)

  case moves, is_check {
    [], True -> Checkmate(in: 0)
    [], False -> Stalemate
    list, True ->
      evaluate_position(list, board_data) - piece_value(Rook)
      |> Value()
    list, False -> Value(evaluate_position(list, board_data))
  }
}
