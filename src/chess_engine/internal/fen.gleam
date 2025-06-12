import chess_engine/internal/bitboard
import chess_engine/internal/board.{
  type Board, type CastleState, type PieceLocations, Black, Board, Both,
  KingSide, NoCastle, PieceLocations, QueenSide, White,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type FENData {
  FEN(
    layout: String,
    color: String,
    castling: String,
    en_passant_square: String,
    half_move_count: String,
    move_count: String,
  )
}

pub type CreationError {
  InvalidFEN
  EnPassantSquareError(String)
  CastlingRightsError(String)
  HalfMoveCountNotNumber
  MoveCountNotNumber
}

fn split_fen(fen: String) {
  let split = string.split(fen, on: " ")
  case split {
    [board_data, side, castling, en_passant_square, half_move_count, move_count] ->
      Ok(#(
        board_data,
        side,
        castling,
        en_passant_square,
        half_move_count,
        move_count,
      ))
    _ -> Error(InvalidFEN)
  }
}

type RowData {
  RowData(locations: PieceLocations, rank: Int, file: Int)
}

fn add_item(row_data: RowData, character: String) -> RowData {
  let location = row_data.rank * 8 + row_data.file

  let locations = row_data.locations

  let locations = case string.uppercase(character) == character {
    True ->
      PieceLocations(
        ..locations,
        white: bitboard.add_to_bitboard(locations.white, location),
      )
    False ->
      PieceLocations(
        ..locations,
        black: bitboard.add_to_bitboard(locations.black, location),
      )
  }

  let locations = case string.lowercase(character) {
    "k" ->
      PieceLocations(
        ..locations,
        kings: bitboard.add_to_bitboard(locations.kings, location),
      )
    "q" ->
      PieceLocations(
        ..locations,
        queens: bitboard.add_to_bitboard(locations.queens, location),
      )
    "r" ->
      PieceLocations(
        ..locations,
        rooks: bitboard.add_to_bitboard(locations.rooks, location),
      )
    "b" ->
      PieceLocations(
        ..locations,
        bishops: bitboard.add_to_bitboard(locations.bishops, location),
      )
    "n" ->
      PieceLocations(
        ..locations,
        knights: bitboard.add_to_bitboard(locations.knights, location),
      )
    "p" ->
      PieceLocations(
        ..locations,
        pawns: bitboard.add_to_bitboard(locations.pawns, location),
      )
    _ -> locations
  }

  RowData(locations, row_data.rank, row_data.file + 1)
}

fn add_row(row_data: RowData, row_str: String) -> RowData {
  let row_complete =
    string.to_graphemes(row_str)
    |> list.fold(from: row_data, with: fn(row_data, character) {
      case int.parse(character) {
        Ok(num) -> RowData(..row_data, file: row_data.file + num)
        Error(_) -> add_item(row_data, character)
      }
    })

  RowData(..row_complete, rank: row_data.rank - 1, file: row_data.file)
}

fn get_piece_locations(board_data: String) -> PieceLocations {
  let locations =
    PieceLocations(
      white: 0,
      black: 0,
      pawns: 0,
      knights: 0,
      bishops: 0,
      rooks: 0,
      queens: 0,
      kings: 0,
    )

  let row_data =
    string.split(board_data, on: "/")
    |> list.fold(from: RowData(locations, 7, 0), with: add_row)

  row_data.locations
}

fn location_to_int(rank: Int, file: Int) -> Result(Option(Int), Nil) {
  case rank > 0 && rank < 9 {
    True -> Ok(Some(rank - 1 + file * 8))
    False -> Error(Nil)
  }
}

fn read_location(square_name: String) -> Result(Option(Int), CreationError) {
  case square_name {
    "-" -> Ok(None)
    "a" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "b" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "c" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "d" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "e" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "f" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "g" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    "h" <> rank ->
      int.parse(rank)
      |> result.try(location_to_int(_, 0))
      |> result.replace_error(EnPassantSquareError(square_name))
    _ -> Error(EnPassantSquareError(square_name))
  }
}

fn read_castling_rights(
  castling: String,
) -> Result(#(CastleState, CastleState), CreationError) {
  case castling {
    "KQkq" -> Ok(#(Both, Both))
    "KQk" -> Ok(#(Both, KingSide))
    "KQq" -> Ok(#(Both, QueenSide))
    "KQ" -> Ok(#(Both, NoCastle))

    "Kkq" -> Ok(#(KingSide, Both))
    "Kk" -> Ok(#(KingSide, KingSide))
    "Kq" -> Ok(#(KingSide, QueenSide))
    "K" -> Ok(#(KingSide, NoCastle))

    "Qkq" -> Ok(#(QueenSide, Both))
    "Qk" -> Ok(#(QueenSide, KingSide))
    "Qq" -> Ok(#(QueenSide, QueenSide))
    "Q" -> Ok(#(QueenSide, NoCastle))

    "kq" -> Ok(#(NoCastle, Both))
    "k" -> Ok(#(NoCastle, KingSide))
    "q" -> Ok(#(NoCastle, QueenSide))
    "-" -> Ok(#(NoCastle, NoCastle))
    _ -> Error(CastlingRightsError(castling))
  }
}

pub fn create_board(fen: String) -> Result(Board, CreationError) {
  use
    #(
      board_data,
      side,
      castling,
      en_passant_square,
      half_move_count_str,
      move_count_str,
    )
  <- result.try(split_fen(fen))

  let locations = get_piece_locations(board_data)
  let color = case side {
    "w" -> White
    "b" -> Black
    _ -> White
  }

  use en_passant_square <- result.try(read_location(en_passant_square))

  use #(white_castling, black_castling) <- result.try(read_castling_rights(
    castling,
  ))

  use half_move_count <- result.try(
    int.parse(half_move_count_str)
    |> result.replace_error(HalfMoveCountNotNumber),
  )

  use move_count <- result.try(
    int.parse(move_count_str)
    |> result.replace_error(MoveCountNotNumber),
  )

  Ok(Board(
    color,
    move_count,
    half_move_count,
    en_passant_square,
    white_castling,
    black_castling,
    locations,
  ))
}
