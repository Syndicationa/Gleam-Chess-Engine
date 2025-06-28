import chess_engine/internal/board/board.{
  type Board, type Color, type Piece, Bishop, Black, King, Knight, Pawn, Queen,
  Rook, White,
}
import chess_engine/internal/board/move.{
  type Move, type MoveReadError, Castle, CastleKingSide, CastleQueenSide, Move,
  NoMove, NoPiece, Promotion, PromotionCapture, RegexIssue, TwoMoves,
  UnknownMove,
}
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result

const algebraic_notation_regex = "([KQRBN])?([a-h]?)([1-8]?)?x?([a-h][1-8])[+#]?=?([QRBN])?|(O-O-O)|(O-O)"

pub fn create_move(
  board_data: Board,
  move_string: String,
  moves: List(Move),
) -> Result(Move, MoveReadError) {
  use regex <- result.try(
    regexp.from_string(algebraic_notation_regex)
    |> result.map_error(RegexIssue),
  )

  let matches = regexp.scan(regex, move_string)

  case matches {
    [] -> Error(NoMove)
    [match] -> from_regex(match, board_data, moves)
    [_, ..] -> Error(TwoMoves)
  }
}

fn from_regex(
  match: regexp.Match,
  board_data: Board,
  moves: List(Move),
) -> Result(Move, MoveReadError) {
  use <- bool.guard(
    match.content == "O-O",
    to_kingside_castle(board_data.active_color),
  )
  use <- bool.guard(
    match.content == "O-O-O",
    to_queenside_castle(board_data.active_color),
  )

  //Submatches go [piece][file][rank][end_square][promotion]

  case match.submatches {
    [piece, file, rank, Some(square)] -> {
      use piece <- result.try(get_piece_type(piece))
      let #(mask, value) = get_mask_and_value(file, rank)
      use target <- result.try(move.to_position(square))

      list.find(moves, fn(move_data) {
        move_data.piece == piece
        && int.bitwise_and(move_data.source, mask) == value
        && move_data.target == target
        && case move_data.data {
          Promotion(_) -> False
          _ -> True
        }
      })
      |> result.replace_error(UnknownMove(match.content))
    }
    [piece, file, rank, Some(square), promotion] -> {
      use piece <- result.try(get_piece_type(piece))
      let #(mask, value) = get_mask_and_value(file, rank)
      use target <- result.try(move.to_position(square))
      let promotion = get_piece_type(promotion) |> result.unwrap(Pawn)

      list.find(moves, fn(move_data) {
        move_data.piece == piece
        && int.bitwise_and(move_data.source, mask) == value
        && move_data.target == target
        && case move_data.data {
          Promotion(piece) | PromotionCapture(piece, _) -> piece == promotion
          _ -> True
        }
      })
      |> result.replace_error(UnknownMove(match.content))
    }

    _ -> Error(UnknownMove(match.content))
  }
}

fn to_kingside_castle(color: Color) {
  let #(source, target) = case color {
    White -> #(4, 6)
    Black -> #(60, 62)
  }

  Ok(Move(King, source, target, Castle(CastleKingSide)))
}

fn to_queenside_castle(color: Color) {
  let #(source, target) = case color {
    White -> #(4, 2)
    Black -> #(60, 58)
  }

  Ok(Move(King, source, target, Castle(CastleQueenSide)))
}

fn get_piece_type(piece: Option(String)) -> Result(Piece, MoveReadError) {
  case piece {
    None -> Ok(Pawn)
    Some("N") -> Ok(Knight)
    Some("B") -> Ok(Bishop)
    Some("R") -> Ok(Rook)
    Some("Q") -> Ok(Queen)
    Some("K") -> Ok(King)
    _ -> Error(NoPiece)
  }
}

fn get_mask_and_value(file: Option(String), rank: Option(String)) -> #(Int, Int) {
  case file, rank {
    None, None -> #(0, 0)
    Some(file), None -> #(
      0o0_7,
      move.to_position(file <> "1") |> result.unwrap(0),
    )
    None, Some(rank) -> #(
      0o7_0,
      move.to_position("a" <> rank) |> result.unwrap(0),
    )
    Some(file), Some(rank) -> #(
      0o7_7,
      move.to_position(file <> rank) |> result.unwrap(0),
    )
  }
}
