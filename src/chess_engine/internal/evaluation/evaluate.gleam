import chess_engine/internal/board/bitboard.{type BitBoard}
import chess_engine/internal/board/board.{
  type Board, type Color, type Piece, Bishop, Knight, Pawn, Queen, Rook,
}
import chess_engine/internal/board/move.{
  type Move, Capture, Castle, EnPassant, Promotion, PromotionCapture,
}
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
  }
}

pub fn piece_value(piece: Piece) -> Int {
  case piece {
    Queen -> 90
    Rook -> 50
    Bishop -> 30
    Knight -> 30
    Pawn -> 10
    _ -> 0
  }
}

pub fn bit_count(source: BitBoard, running_count: Int) {
  use <- bool.guard(source == 0, running_count)

  let lsb = bitboard.isolate_lsb(source)
  bit_count(source - lsb, running_count + 1)
}

fn side_value(board_data: Board, side: Color) {
  let queens =
    int.bitwise_and(
      board.get_color_bitboard(board_data, side),
      board_data.pieces.queens,
    )
  let rooks =
    int.bitwise_and(
      board.get_color_bitboard(board_data, side),
      board_data.pieces.rooks,
    )
  let bishops =
    int.bitwise_and(
      board.get_color_bitboard(board_data, side),
      board_data.pieces.bishops,
    )
  let knights =
    int.bitwise_and(
      board.get_color_bitboard(board_data, side),
      board_data.pieces.knights,
    )
  let pawns =
    int.bitwise_and(
      board.get_color_bitboard(board_data, side),
      board_data.pieces.pawns,
    )

  let queens = bit_count(queens, 0) * 90
  let rooks = bit_count(rooks, 0) * 50
  let bishops = bit_count(bishops, 0) * 30
  let knights = bit_count(knights, 0) * 30
  let pawns = bit_count(pawns, 0) * 10

  queens + rooks + bishops + knights + pawns
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
  let is_check =
    move_generation.in_check(
      move_dictionary,
      board_data,
      board_data.active_color,
    )

  case moves, is_check {
    [], True -> Checkmate(in: 0)
    [], False -> Stalemate
    list, True ->
      evaluate_position(list, board_data) - piece_value(Rook)
      |> Value()
    list, False -> Value(evaluate_position(list, board_data))
  }
}
