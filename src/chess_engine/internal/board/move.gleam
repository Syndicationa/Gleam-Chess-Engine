import chess_engine/internal/board/bitboard
import chess_engine/internal/board/board.{
  type Board, type Piece, Bishop, Black, Board, Both, King, KingSide, Knight,
  NoCastle, Pawn, Queen, QueenSide, Rook, White,
}
import chess_engine/internal/board/fen
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result

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

pub fn run_en_passant(board: Board, move: Move) -> Board {
  case move.data {
    EnPassant -> remove_en_passanted(board) |> standard_move(move)
    _ -> board
  }
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

fn piece_to_string(piece: Piece) -> String {
  case piece {
    Queen -> "q"
    Rook -> "r"
    Bishop -> "b"
    Knight -> "n"
    _ -> ""
  }
}

pub fn to_string(move: Move) -> String {
  case move.data {
    Normal | Capture(_) | EnPassant ->
      position_to_string(move.source) <> position_to_string(move.target)
    Castle(CastleKingSide) -> "O-O"
    Castle(CastleQueenSide) -> "O-O-O"
    Promotion(target) | PromotionCapture(target, _) ->
      position_to_string(move.source)
      <> position_to_string(move.target)
      <> piece_to_string(target)
  }
}

pub type MoveReadError {
  RegexIssue(regexp.CompileError)
  NoMove
  TwoMoves
  UnknownMove(String)
  InvalidLocation(String)
  NoPiece
  CannotTargetOwnPieces
  InvalidState
}

pub fn error_to_string(error: MoveReadError) -> String {
  case error {
    RegexIssue(_) -> "Regex Failed!"
    NoMove -> "No move in string"
    TwoMoves -> "Two moves in string"
    UnknownMove(str) -> str <> " is not a known type of move"
    InvalidLocation(str) -> str <> " is not a valid location"
    NoPiece -> "There is no piece at this location"
    CannotTargetOwnPieces -> "You cannot capture one of your pieces"
    InvalidState -> "The board has reached an invalid state"
  }
}

pub fn from_string(
  str: String,
  board_data: Board,
) -> Result(Move, MoveReadError) {
  use regex <- result.try(
    regexp.from_string("([a-h][1-8])([a-h][1-8])=?([QRBNqrbn]?)|O-O-O|O-O")
    |> result.map_error(RegexIssue),
  )
  let matches = regexp.scan(regex, str)

  case matches {
    [] -> Error(NoMove)
    [match] -> from_regex(match, board_data)
    [_, ..] -> Error(TwoMoves)
  }
}

fn from_regex(
  match: regexp.Match,
  board_data: Board,
) -> Result(Move, MoveReadError) {
  case match.content, match.submatches {
    _, [Some(start), Some(destination), None] -> {
      use source_int <- result.try(to_position(start))
      use target_int <- result.try(to_position(destination))
      let piece_result =
        board.get_piece_at_location(board_data, source_int)
        |> option.to_result(NoPiece)
      use piece <- result.try(piece_result)

      let is_opponent_color =
        board.get_color_at_location(board_data, target_int)
        == Some(board.opposite_color(board_data.active_color))
      let target_piece = board.get_piece_at_location(board_data, target_int)

      case is_opponent_color, target_piece {
        False, Some(_) -> Error(CannotTargetOwnPieces)
        True, None -> Error(InvalidState)
        _, target_piece ->
          to_move(board_data, source_int, target_int, piece, target_piece, None)
          |> Ok
      }
    }
    _, [Some(start), Some(destination), Some(promotion)] -> {
      use source_int <- result.try(to_position(start))
      use target_int <- result.try(to_position(destination))
      let piece_result =
        board.get_piece_at_location(board_data, source_int)
        |> option.to_result(NoPiece)
      use piece <- result.try(piece_result)

      let is_opponent_color =
        board.get_color_at_location(board_data, target_int)
        == Some(board.opposite_color(board_data.active_color))
      let target_piece = board.get_piece_at_location(board_data, target_int)

      let promotion_piece = case promotion {
        "Q" -> Some(Queen)
        "R" -> Some(Rook)
        "B" -> Some(Bishop)
        "N" -> Some(Knight)
        _ -> None
      }

      case is_opponent_color, target_piece {
        False, Some(_) -> Error(CannotTargetOwnPieces)
        True, None -> Error(InvalidState)
        _, target_piece ->
          to_move(
            board_data,
            source_int,
            target_int,
            piece,
            target_piece,
            promotion_piece,
          )
          |> Ok
      }
    }
    "O-O", _ -> {
      let #(source, target) = case board_data.active_color {
        White -> #(4, 6)
        Black -> #(60, 62)
      }

      Ok(Move(King, source, target, Castle(CastleKingSide)))
    }
    "O-O-O", _ -> {
      let #(source, target) = case board_data.active_color {
        White -> #(4, 2)
        Black -> #(60, 58)
      }
      Ok(Move(King, source, target, Castle(CastleQueenSide)))
    }
    move, _ -> Error(UnknownMove(move))
  }
}

pub fn to_move(
  board_data: Board,
  source: Int,
  target: Int,
  piece: Piece,
  captured_piece: Option(Piece),
  promotion: Option(Piece),
) -> Move {
  let distance = source - target
  case piece, captured_piece, promotion {
    Pawn, None, None if Some(target) == board_data.en_passant_square ->
      Move(Pawn, source, target, data: EnPassant)
    Pawn, None, Some(promotion) ->
      Move(Pawn, source, target, data: Promotion(promotion))
    Pawn, Some(target_piece), Some(promotion) ->
      Move(
        Pawn,
        source,
        target,
        data: PromotionCapture(promotion, target_piece),
      )
    King, None, None if distance == -2 -> {
      let #(source, target) = case board_data.active_color {
        White -> #(4, 2)
        Black -> #(60, 58)
      }
      Move(King, source, target, Castle(CastleQueenSide))
    }
    King, None, None if distance == 2 -> {
      let #(source, target) = case board_data.active_color {
        White -> #(4, 6)
        Black -> #(60, 62)
      }

      Move(King, source, target, Castle(CastleKingSide))
    }
    piece, None, _ -> Move(piece, source, target, Normal)
    piece, Some(target_piece), _ ->
      Move(piece, source, target, Capture(target_piece))
  }
}

pub fn to_position(square_name: String) -> Result(Int, MoveReadError) {
  case square_name {
    "a" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 0))
      |> result.replace_error(InvalidLocation(square_name))
    "b" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 1))
      |> result.replace_error(InvalidLocation(square_name))
    "c" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 2))
      |> result.replace_error(InvalidLocation(square_name))
    "d" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 3))
      |> result.replace_error(InvalidLocation(square_name))
    "e" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 4))
      |> result.replace_error(InvalidLocation(square_name))
    "f" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 5))
      |> result.replace_error(InvalidLocation(square_name))
    "g" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 6))
      |> result.replace_error(InvalidLocation(square_name))
    "h" <> rank ->
      int.parse(rank)
      |> result.try(fen.location_to_int(_, 7))
      |> result.replace_error(InvalidLocation(square_name))
    _ -> Error(InvalidLocation(square_name))
  }
}
