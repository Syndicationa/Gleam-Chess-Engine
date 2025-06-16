import chess_engine/internal/board/bitboard
import chess_engine/internal/board/board.{type Board, type Color, Black, White}
import chess_engine/internal/helper
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string_tree.{type StringTree}

fn piece_character(board: Board, idx: Int) {
  let is_king = bitboard.is_on_bitboard(board.pieces.kings, idx)
  let is_queen = bitboard.is_on_bitboard(board.pieces.queens, idx)
  let is_rook = bitboard.is_on_bitboard(board.pieces.rooks, idx)
  let is_bishop = bitboard.is_on_bitboard(board.pieces.bishops, idx)
  let is_knight = bitboard.is_on_bitboard(board.pieces.knights, idx)
  let is_pawn = bitboard.is_on_bitboard(board.pieces.pawns, idx)

  let count =
    helper.ternary(is_pawn, 1, 0)
    + helper.ternary(is_knight, 1, 0)
    + helper.ternary(is_bishop, 1, 0)
    + helper.ternary(is_rook, 1, 0)
    + helper.ternary(is_queen, 1, 0)
    + helper.ternary(is_king, 1, 0)

  let diagonal_value = { int.bitwise_shift_right(idx, 3) + idx } % 2

  case board.get_color_at_location(board, idx) {
    _ if count >= 2 -> int.to_string(count)
    Some(White) if is_king -> "♔"
    Some(White) if is_queen -> "♕"
    Some(White) if is_rook -> "♖"
    Some(White) if is_bishop -> "♗"
    Some(White) if is_knight -> "♘"
    Some(White) if is_pawn -> "♙"
    Some(Black) if is_king -> "♚"
    Some(Black) if is_queen -> "♛"
    Some(Black) if is_rook -> "♜"
    Some(Black) if is_bishop -> "♝"
    Some(Black) if is_knight -> "♞"
    Some(Black) if is_pawn -> "♟"
    _ if diagonal_value == 0 -> "#"
    _ -> " "
  }
}

fn tree_for_row(board: Board, row_idx: Int, perspective: Color) -> StringTree {
  use <- bool.lazy_guard(row_idx > 7 || row_idx < 0, fn() {
    case perspective {
      White -> "  a b c d e f g h"
      Black -> "  h g f e d c b a"
    }
    |> string_tree.from_string()
  })

  let square = int.bitwise_shift_left(row_idx, 3)

  case perspective {
    White -> list.range(square, square + 7)
    Black -> list.range(square + 7, square)
  }
  |> list.fold(
    string_tree.from_string(int.to_string(row_idx + 1) <> " "),
    fn(tree, idx) {
      string_tree.append(tree, piece_character(board, idx))
      |> string_tree.append(" ")
    },
  )
}

pub fn to_string(board: Board, perspective: Color) {
  case perspective {
    White -> list.range(7, -1)
    Black -> list.range(0, 8)
  }
  |> list.map(tree_for_row(board, _, perspective))
  |> string_tree.join("\n")
  |> string_tree.append("\n")
  |> string_tree.to_string()
}
