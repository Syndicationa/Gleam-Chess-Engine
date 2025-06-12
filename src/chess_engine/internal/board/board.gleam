import chess_engine/internal/board/bitboard.{type BitBoard}
import gleam/option.{type Option, None, Some}

pub type Color {
  White
  Black
}

pub fn opposite_color(color: Color) -> Color {
  case color {
    White -> Black
    Black -> White
  }
}

pub type Piece {
  King
  Queen
  Rook
  Bishop
  Knight
  Pawn
}

pub type CastleState {
  NoCastle
  KingSide
  QueenSide
  Both
}

pub type PieceLocations {
  PieceLocations(
    //Color Bitboards
    white: BitBoard,
    black: BitBoard,
    //Piece Bitboards
    pawns: BitBoard,
    knights: BitBoard,
    bishops: BitBoard,
    rooks: BitBoard,
    queens: BitBoard,
    kings: BitBoard,
  )
}

pub type Board {
  Board(
    active_color: Color,
    move_count: Int,
    half_move_count: Int,
    en_passant_square: Option(Int),
    // Castling rights
    white_castling: CastleState,
    black_castling: CastleState,
    pieces: PieceLocations,
  )
}

pub fn get_player_castling(board: Board) {
  case board.active_color {
    White -> board.white_castling
    Black -> board.black_castling
  }
}

pub fn get_opponent_castling(board: Board) {
  case board.active_color {
    White -> board.black_castling
    Black -> board.white_castling
  }
}

pub fn get_color_bitboard(board: Board, color: Color) {
  case color {
    White -> board.pieces.white
    Black -> board.pieces.black
  }
}

pub fn get_opponent_color_bitboard(board: Board, color: Color) {
  case color {
    White -> board.pieces.black
    Black -> board.pieces.white
  }
}

pub fn get_player_bitboard(board: Board) {
  case board.active_color {
    White -> board.pieces.white
    Black -> board.pieces.black
  }
}

pub fn get_opponent_bitboard(board: Board) {
  case board.active_color {
    White -> board.pieces.black
    Black -> board.pieces.white
  }
}

pub fn get_piece_bitboard(board: Board, piece: Piece) {
  case piece {
    King -> board.pieces.kings
    Queen -> board.pieces.queens
    Rook -> board.pieces.rooks
    Bishop -> board.pieces.bishops
    Knight -> board.pieces.knights
    Pawn -> board.pieces.pawns
  }
}

pub fn get_piece_at_location(board: Board, idx: Int) -> Option(Piece) {
  let is_pawn = bitboard.is_on_bitboard(board.pieces.pawns, idx)
  let is_knight = bitboard.is_on_bitboard(board.pieces.knights, idx)
  let is_bishop = bitboard.is_on_bitboard(board.pieces.bishops, idx)
  let is_rook = bitboard.is_on_bitboard(board.pieces.rooks, idx)
  let is_queen = bitboard.is_on_bitboard(board.pieces.queens, idx)
  let is_king = bitboard.is_on_bitboard(board.pieces.kings, idx)

  case Nil {
    _ if is_pawn -> Some(Pawn)
    _ if is_knight -> Some(Knight)
    _ if is_bishop -> Some(Bishop)
    _ if is_rook -> Some(Rook)
    _ if is_queen -> Some(Queen)
    _ if is_king -> Some(King)
    _ -> None
  }
}

pub fn set_player_castling(board: Board, to: CastleState) -> Board {
  case board.active_color {
    White -> Board(..board, white_castling: to)
    Black -> Board(..board, black_castling: to)
  }
}

pub fn set_opponent_castling(board: Board, to: CastleState) -> Board {
  case board.active_color {
    White -> Board(..board, black_castling: to)
    Black -> Board(..board, white_castling: to)
  }
}

pub fn set_player_bitboard(board: Board, to: BitBoard) -> Board {
  case board.active_color {
    White -> Board(..board, pieces: PieceLocations(..board.pieces, white: to))
    Black -> Board(..board, pieces: PieceLocations(..board.pieces, black: to))
  }
}

pub fn set_opponent_bitboard(board: Board, to: BitBoard) -> Board {
  case board.active_color {
    White -> Board(..board, pieces: PieceLocations(..board.pieces, black: to))
    Black -> Board(..board, pieces: PieceLocations(..board.pieces, white: to))
  }
}

pub fn set_piece_bitboard(board: Board, piece: Piece, to: BitBoard) -> Board {
  case piece {
    King -> Board(..board, pieces: PieceLocations(..board.pieces, kings: to))
    Queen -> Board(..board, pieces: PieceLocations(..board.pieces, queens: to))
    Rook -> Board(..board, pieces: PieceLocations(..board.pieces, rooks: to))
    Bishop ->
      Board(..board, pieces: PieceLocations(..board.pieces, bishops: to))
    Knight ->
      Board(..board, pieces: PieceLocations(..board.pieces, knights: to))
    Pawn -> Board(..board, pieces: PieceLocations(..board.pieces, pawns: to))
  }
}
