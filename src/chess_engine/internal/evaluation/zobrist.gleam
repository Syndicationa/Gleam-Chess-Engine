import chess_engine/internal/board/bitboard
import chess_engine/internal/board/board.{
  type Board, type CastleState, type Color, type Piece, Bishop, Black, Both,
  King, KingSide, Knight, NoCastle, Pawn, Queen, QueenSide, Rook, White,
}
import chess_engine/internal/board/move.{
  type CastleDirection, type Move, Capture, Castle, CastleKingSide,
  CastleQueenSide, EnPassant, Normal, Promotion, PromotionCapture,
}
import chess_engine/internal/helper
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result

fn xor_and_shift_left(value: Int, shift: Int) {
  int.bitwise_shift_left(value, shift)
  |> int.bitwise_exclusive_or(value)
}

fn xor_and_shift_right(value: Int, shift: Int) {
  int.bitwise_shift_right(value, shift)
  |> int.bitwise_exclusive_or(value)
}

pub fn random(seed seed: Int) {
  seed
  // This enforces the number to be 64 bit
  |> int.bitwise_and(bitboard.full_bitboard)
  // This set of shifts is stolen from Wikipedia
  |> xor_and_shift_left(13)
  |> xor_and_shift_right(7)
  |> xor_and_shift_left(17)
}

pub opaque type SquareGenerator {
  SquareGenerator(
    king: Int,
    queen: Int,
    rook: Int,
    bishop: Int,
    knight: Int,
    pawn: Int,
    is_black: Int,
  )
}

fn get_square_value(square_generator: SquareGenerator, piece: Piece) {
  case piece {
    King -> square_generator.king
    Queen -> square_generator.queen
    Rook -> square_generator.rook
    Bishop -> square_generator.bishop
    Knight -> square_generator.knight
    Pawn -> square_generator.pawn
  }
}

fn create_hash_for_square(
  accumulator tuple: #(Int, Dict(Int, SquareGenerator)),
  index location: Int,
) -> #(Int, Dict(Int, SquareGenerator)) {
  let #(starting_seed, dictionary) = tuple

  let king = random(seed: starting_seed)
  let queen = random(seed: king)
  let rook = random(seed: queen)
  let bishop = random(seed: rook)
  let knight = random(seed: bishop)
  let pawn = random(seed: knight)
  let is_black = random(seed: pawn)

  #(
    is_black,
    dict.insert(
      dictionary,
      location,
      SquareGenerator(king:, queen:, rook:, bishop:, knight:, pawn:, is_black:),
    ),
  )
}

pub opaque type HashGenerator {
  HashGenerator(
    squares: Dict(Int, SquareGenerator),
    black_turn: Int,
    white_castle_kingside: Int,
    white_castle_queenside: Int,
    black_castle_kingside: Int,
    black_castle_queenside: Int,
    en_passant_file_a: Int,
    en_passant_file_b: Int,
    en_passant_file_c: Int,
    en_passant_file_d: Int,
    en_passant_file_e: Int,
    en_passant_file_f: Int,
    en_passant_file_g: Int,
    en_passant_file_h: Int,
  )
}

// fn ignore_list_values(func: fn(a) -> #(a, v)) {
//   fn(acc, _) { func(acc) }
// }
///This function builds a hash generator of the Zobrist Hashing for Transposition
pub fn create_hash(seed seed: Int) -> HashGenerator {
  let #(seed, squares) =
    list.range(0, 63)
    |> list.fold(#(seed, dict.new()), create_hash_for_square)

  let black_turn = random(seed: seed)
  let white_castle_kingside = random(seed: black_turn)
  let white_castle_queenside = random(seed: white_castle_kingside)
  let black_castle_kingside = random(seed: white_castle_queenside)
  let black_castle_queenside = random(seed: black_castle_kingside)
  let en_passant_file_a = random(seed: black_castle_queenside)
  let en_passant_file_b = random(seed: en_passant_file_a)
  let en_passant_file_c = random(seed: en_passant_file_b)
  let en_passant_file_d = random(seed: en_passant_file_c)
  let en_passant_file_e = random(seed: en_passant_file_d)
  let en_passant_file_f = random(seed: en_passant_file_e)
  let en_passant_file_g = random(seed: en_passant_file_f)
  let en_passant_file_h = random(seed: en_passant_file_g)

  HashGenerator(
    squares:,
    black_turn:,
    white_castle_kingside:,
    white_castle_queenside:,
    black_castle_kingside:,
    black_castle_queenside:,
    en_passant_file_a:,
    en_passant_file_b:,
    en_passant_file_c:,
    en_passant_file_d:,
    en_passant_file_e:,
    en_passant_file_f:,
    en_passant_file_g:,
    en_passant_file_h:,
  )
}

fn encode_positions(board_data: Board) {
  fn(encoding: Int, index: Int, square: SquareGenerator) {
    encoding
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.kings, index),
      square.king,
      0,
    ))
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.queens, index),
      square.queen,
      0,
    ))
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.rooks, index),
      square.rook,
      0,
    ))
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.bishops, index),
      square.bishop,
      0,
    ))
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.knights, index),
      square.knight,
      0,
    ))
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.pawns, index),
      square.pawn,
      0,
    ))
    |> int.bitwise_exclusive_or(helper.ternary(
      bitboard.is_on_bitboard(board_data.pieces.black, index),
      square.is_black,
      0,
    ))
  }
}

fn encode_castling(
  castle_state: CastleState,
  kingside_value: Int,
  queenside_value: Int,
) {
  case castle_state {
    Both -> int.bitwise_exclusive_or(kingside_value, queenside_value)
    KingSide -> kingside_value
    QueenSide -> queenside_value
    NoCastle -> 0
  }
}

fn encode_en_passant(generator: HashGenerator, board_data: Board) -> Int {
  case board_data.en_passant_square {
    None -> 0
    Some(square) -> {
      let file = int.bitwise_and(square, 7)

      case file {
        0 -> generator.en_passant_file_a
        1 -> generator.en_passant_file_b
        2 -> generator.en_passant_file_c
        3 -> generator.en_passant_file_d
        4 -> generator.en_passant_file_e
        5 -> generator.en_passant_file_f
        6 -> generator.en_passant_file_g
        7 -> generator.en_passant_file_h
        _ -> 0
      }
    }
  }
}

///This is an expensive way to get the Zobrist Hash of a Board from scratch using the relevant generator
pub fn encode_board(generator: HashGenerator, board_data: Board) {
  let square_encoding =
    dict.fold(generator.squares, 0, encode_positions(board_data))

  let color_value = case board_data.active_color {
    White -> 0
    Black -> generator.black_turn
  }

  let white_castle =
    encode_castling(
      board_data.white_castling,
      generator.white_castle_kingside,
      generator.white_castle_queenside,
    )

  let black_castle =
    encode_castling(
      board_data.black_castling,
      generator.black_castle_kingside,
      generator.black_castle_queenside,
    )

  let en_passant = encode_en_passant(generator, board_data)

  int.bitwise_exclusive_or(square_encoding, color_value)
  |> int.bitwise_exclusive_or(white_castle)
  |> int.bitwise_exclusive_or(black_castle)
  |> int.bitwise_exclusive_or(en_passant)
}

fn encode_castle_move(
  generator: HashGenerator,
  hash_so_far: Int,
  move_data: Move,
  direction: CastleDirection,
  color: Color,
) -> Result(Int, Nil) {
  let #(initial, final) = case direction {
    CastleKingSide -> {
      #(move_data.target + 1, move_data.target - 1)
    }
    CastleQueenSide -> {
      #(move_data.target - 2, move_data.target + 1)
    }
  }

  use rook_initial <- result.try(dict.get(generator.squares, initial))
  use rook_final <- result.try(dict.get(generator.squares, final))

  int.bitwise_exclusive_or(rook_initial.is_black, rook_final.is_black)
  |> helper.ternary(color == Black, _, 0)
  |> int.bitwise_exclusive_or(hash_so_far)
  |> int.bitwise_exclusive_or(get_square_value(rook_initial, Rook))
  |> int.bitwise_exclusive_or(get_square_value(rook_final, Rook))
  |> Ok()
}

///This is the cheaper way to update a Zobrist Hash of a Board using the move that changed the board state
pub fn encode_move(
  generator: HashGenerator,
  old_hash: Int,
  old_board: Board,
  new_board: Board,
  move_data: Move,
) -> Result(Int, Nil) {
  //Handles the basic part of the move first
  use source_square <- result.try(dict.get(generator.squares, move_data.source))
  use target_square <- result.try(dict.get(generator.squares, move_data.target))

  let wck = generator.white_castle_kingside
  let wcq = generator.white_castle_queenside
  let bck = generator.black_castle_kingside
  let bcq = generator.black_castle_queenside

  let basic_move_hash =
    //This handles the movement of the piece if this is the black turn
    int.bitwise_exclusive_or(source_square.is_black, target_square.is_black)
    |> helper.ternary(old_board.active_color == Black, _, 0)
    |> int.bitwise_exclusive_or(old_hash)
    //Toggle Turn
    |> int.bitwise_exclusive_or(generator.black_turn)
    //Handle the Piece Movement
    |> int.bitwise_exclusive_or(get_square_value(source_square, move_data.piece))
    |> int.bitwise_exclusive_or(get_square_value(target_square, move_data.piece))
    //Handle En Passant changes
    |> int.bitwise_exclusive_or(encode_en_passant(generator, old_board))
    |> int.bitwise_exclusive_or(encode_en_passant(generator, new_board))
    //Handle Castling State Changes
    |> int.bitwise_exclusive_or(encode_castling(
      old_board.white_castling,
      wck,
      wcq,
    ))
    |> int.bitwise_exclusive_or(encode_castling(
      old_board.black_castling,
      bck,
      bcq,
    ))
    |> int.bitwise_exclusive_or(encode_castling(
      new_board.white_castling,
      wck,
      wcq,
    ))
    |> int.bitwise_exclusive_or(encode_castling(
      new_board.black_castling,
      bck,
      bcq,
    ))

  case move_data.data {
    Normal -> Ok(basic_move_hash)
    Capture(taken_piece) ->
      helper.ternary(old_board.active_color != Black, target_square.is_black, 0)
      |> int.bitwise_exclusive_or(get_square_value(target_square, taken_piece))
      |> int.bitwise_exclusive_or(basic_move_hash)
      |> Ok
    Promotion(promotion) ->
      basic_move_hash
      |> int.bitwise_exclusive_or(get_square_value(target_square, Pawn))
      |> int.bitwise_exclusive_or(get_square_value(target_square, promotion))
      |> Ok
    PromotionCapture(promotion, taken) ->
      helper.ternary(old_board.active_color != Black, target_square.is_black, 0)
      |> int.bitwise_exclusive_or(get_square_value(target_square, Pawn))
      |> int.bitwise_exclusive_or(get_square_value(target_square, promotion))
      |> int.bitwise_exclusive_or(get_square_value(target_square, taken))
      |> int.bitwise_exclusive_or(basic_move_hash)
      |> Ok
    Castle(direction) ->
      encode_castle_move(
        generator,
        basic_move_hash,
        move_data,
        direction,
        old_board.active_color,
      )
    EnPassant -> {
      use en_passant_square_idx <- result.try(option.to_result(
        old_board.en_passant_square,
        Nil,
      ))
      use en_passant_square <- result.try(dict.get(
        generator.squares,
        en_passant_square_idx,
      ))

      helper.ternary(
        old_board.active_color != Black,
        en_passant_square.is_black,
        0,
      )
      |> int.bitwise_exclusive_or(get_square_value(en_passant_square, Pawn))
      |> int.bitwise_exclusive_or(basic_move_hash)
      |> Ok
    }
  }
}
