import chess_engine/internal/bitboard.{type BitBoard}
import chess_engine/internal/board.{
  type Board, type Color, type Piece, Bishop, Black, King, Knight, Pawn, Queen,
  Rook, White,
}
import chess_engine/internal/move.{
  type Move, Capture, Castle, CastleKingSide, CastleQueenSide, EnPassant, Move,
  Normal, Promotion, PromotionCapture,
}
import chess_engine/internal/move_dictionary.{
  type BishopMove, type RookMove, type SlidingDictionary,
}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/yielder

const knight_moves = [
  #(2, 1),
  #(1, 2),
  #(-2, 1),
  #(-1, 2),
  #(2, -1),
  #(1, -2),
  #(-2, -1),
  #(-1, -2),
]

const king_moves = [
  #(1, 1),
  #(1, 1),
  #(-1, 1),
  #(-1, 1),
  #(1, -1),
  #(1, -1),
  #(-1, -1),
  #(-1, -1),
]

fn long_bit_length(number: Int, count: Int) -> Int {
  case number {
    //This should never get hit
    0 -> count
    1 -> count + 1
    num ->
      int.bitwise_shift_right(num, 1)
      |> long_bit_length(count + 1)
  }
}

///This covers some powers of 2 or passes it onto long bit length
fn faster_bit_length(number: Int) -> Int {
  case number {
    0 -> 0
    1 -> 1
    2 -> 2
    4 -> 3
    8 -> 4
    16 -> 5
    32 -> 6
    64 -> 7
    128 -> 8
    256 -> 9
    1024 -> 10
    2048 -> 11
    4096 -> 12
    8192 -> 13
    16_384 -> 14
    32_768 -> 15
    65_536 -> 16
    _ -> long_bit_length(number, 0)
  }
}

fn generate_slides(
  square_list: List(Int),
  reverse: List(Int),
  friendly: BitBoard,
  enemy: BitBoard,
) -> List(Int) {
  let player =
    list.fold(reverse, 1, fn(i, index) {
      int.bitwise_shift_left(i, 1) + bitboard.value_on_bitboard(friendly, index)
    })
  let complete =
    list.fold(reverse, 1, fn(i, index) {
      int.bitwise_shift_left(i, 1) + bitboard.value_on_bitboard(enemy, index)
    })
    |> int.bitwise_shift_left(1)
    |> int.bitwise_or(player)

  let count =
    complete
    |> int.bitwise_not
    |> int.add(1)
    |> int.bitwise_and(complete)
    |> faster_bit_length()
    |> int.subtract(1)

  list.take(square_list, count)
}

pub type GenerationError {
  LocationBeyond64
  InvalidPieceType(Piece)
}

fn generate_rook_moves(
  moves: List(Int),
  move: RookMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> List(Int) {
  moves
  |> list.append(generate_slides(move.up, move.up_reverse, friendly, enemy))
  |> list.append(generate_slides(move.down, move.down_reverse, friendly, enemy))
  |> list.append(generate_slides(move.left, move.left_reverse, friendly, enemy))
  |> list.append(generate_slides(
    move.right,
    move.right_reverse,
    friendly,
    enemy,
  ))
}

fn generate_bishop_moves(
  moves: List(Int),
  move: BishopMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> List(Int) {
  moves
  |> list.append(generate_slides(
    move.up_left,
    move.up_left_reverse,
    friendly,
    enemy,
  ))
  |> list.append(generate_slides(
    move.up_right,
    move.up_right_reverse,
    friendly,
    enemy,
  ))
  |> list.append(generate_slides(
    move.down_left,
    move.down_left_reverse,
    friendly,
    enemy,
  ))
  |> list.append(generate_slides(
    move.down_right,
    move.down_right_reverse,
    friendly,
    enemy,
  ))
}

fn generate_sliding_move(
  table: SlidingDictionary,
  piece: Piece,
  location: Int,
  friendly: BitBoard,
  enemy: BitBoard,
) -> Result(List(Int), GenerationError) {
  use moves <- result.try(
    dict.get(table, location) |> result.replace_error(LocationBeyond64),
  )

  case piece {
    Queen ->
      generate_rook_moves([], moves.rook, friendly, enemy)
      |> generate_bishop_moves(moves.bishop, friendly, enemy)
      |> Ok()
    Rook -> Ok(generate_rook_moves([], moves.rook, friendly, enemy))
    Bishop -> Ok(generate_bishop_moves([], moves.bishop, friendly, enemy))
    piece -> Error(InvalidPieceType(piece))
  }
}

fn generate_moves_from_list(
  move_list: List(#(Int, Int)),
  location: Int,
  friendly: BitBoard,
) -> List(Int) {
  move_list
  |> list.filter_map(fn(value) {
    let #(d_x, d_y) = value
    let x = int.bitwise_and(location, 0o0_7)
    let y = int.bitwise_and(location, 0o7_0)

    case x + d_x, y + d_y {
      x, y if x < 0 || y < 0 || x >= 8 || y >= 8 -> Error(Nil)
      x, y -> int.bitwise_shift_left(y, 3) + x |> Ok
    }
    |> result.try(fn(new_location) {
      case bitboard.value_on_bitboard(friendly, new_location) {
        1 -> Error(Nil)
        n -> Ok(n)
      }
    })
  })
}

fn generate_castles(player_castle_state) {
  todo
}

fn generate_pawn_moves(
  location: Int,
  direction: Color,
  friendly: BitBoard,
  enemy: BitBoard,
  en_passant_square: Int,
) {
  let rank = int.bitwise_shift_right(location, 3)
  let file = int.bitwise_and(location, 7)

  let #(direction_int, on_starting_rank) = case direction {
    White -> #(0o1_0, 1 == rank)
    //I want this to be a negative octal
    Black -> #(-8, 6 == rank)
  }

  let blocking_bitboard = int.bitwise_or(friendly, enemy)

  let forward_square = location + direction_int
  let forward_2 = forward_square + direction_int
  let attack_left = forward_square - 1
  let attack_right = forward_square + 1

  let can_move_forward =
    blocking_bitboard
    |> bitboard.value_on_bitboard(forward_square)
    |> fn(x) { x == 0 }

  let can_move_forward_2 =
    blocking_bitboard
    |> bitboard.value_on_bitboard(forward_2)
    |> fn(x) { x == 0 }
    |> bool.and(can_move_forward)
    |> bool.and(on_starting_rank)

  let can_attack_left =
    enemy
    |> bitboard.value_on_bitboard(attack_left)
    |> fn(x) { x == 1 }
    |> bool.or(en_passant_square == attack_right)
    |> bool.and(file > 0)

  let can_attack_right =
    enemy
    |> bitboard.value_on_bitboard(attack_right)
    |> fn(x) { x == 1 }
    |> bool.or(en_passant_square == attack_right)
    |> bool.and(file < 7)

  [
    #(can_move_forward, forward_square),
    #(can_move_forward_2, forward_2),
    #(can_attack_left, attack_left),
    #(can_attack_right, attack_right),
  ]
  |> list.filter_map(fn(dual) {
    let #(boolean, square) = dual
    case boolean {
      True -> Ok(square)
      False -> Error(Nil)
    }
  })
}

fn create_pawn_move(
  start: Int,
  destination: Int,
  captured_piece: Option(Piece),
) -> List(Move) {
  let rank = int.bitwise_shift_right(destination, 3)

  case rank, captured_piece {
    7, Some(piece) | 0, Some(piece) -> [
      Move(Pawn, start, destination, PromotionCapture(Queen, piece)),
      Move(Pawn, start, destination, PromotionCapture(Rook, piece)),
      Move(Pawn, start, destination, PromotionCapture(Bishop, piece)),
      Move(Pawn, start, destination, PromotionCapture(Knight, piece)),
    ]
    7, None | 0, None -> [
      Move(Pawn, start, destination, Promotion(Queen)),
      Move(Pawn, start, destination, Promotion(Rook)),
      Move(Pawn, start, destination, Promotion(Bishop)),
      Move(Pawn, start, destination, Promotion(Knight)),
    ]
    5, None if destination - start != 8 -> [
      Move(Pawn, start, destination, EnPassant),
    ]
    2, None if destination - start != -8 -> [
      Move(Pawn, start, destination, EnPassant),
    ]
    _, Some(piece) -> [Move(Pawn, start, destination, Capture(piece))]
    _, None -> [Move(Pawn, start, destination, Normal)]
  }
}

fn create_move(
  piece: Piece,
  start: Int,
  destination: Int,
  captured_piece: Option(Piece),
) -> List(Move) {
  case piece, captured_piece {
    Pawn, captured -> create_pawn_move(start, destination, captured)
    King, None if start - destination == 2 -> [
      Move(piece, start, destination, Castle(CastleKingSide)),
    ]
    King, None if start - destination == -2 -> [
      Move(piece, start, destination, Castle(CastleQueenSide)),
    ]
    piece, None -> [Move(piece, start, destination, Normal)]
    piece, Some(target) -> [Move(piece, start, destination, Capture(target))]
  }
}

fn determine_knight_check(board_data: Board, king_location: Int) -> Bool {
  board.get_opponent_bitboard(board_data)
  |> int.bitwise_and(board_data.pieces.knights)
  //This will generate a bitboard of all non-enemy knight squares
  |> bitboard.not()
  |> generate_moves_from_list(knight_moves, king_location, _)
  |> fn(x) {
    case x {
      //If there are no enemy knights a knight move away, then we cannot be in check
      [] -> False
      _ -> True
    }
  }
}

fn determine_bishop_check(
  table: SlidingDictionary,
  board_data: Board,
  king_location: Int,
) -> Result(Bool, GenerationError) {
  let bishop_queen =
    board_data.pieces.bishops
    |> int.bitwise_or(board_data.pieces.queens)
    |> int.bitwise_and(board.get_opponent_bitboard(board_data))

  let everything_else =
    board_data.pieces.white
    |> int.bitwise_or(board_data.pieces.black)
    //This will cut out the enemy bishops and queens as they exist on the every piece bitboard
    |> int.bitwise_exclusive_or(bishop_queen)

  use moves <- result.try(
    dict.get(table, king_location) |> result.replace_error(LocationBeyond64),
  )

  let bishop_slides =
    generate_bishop_moves([], moves.bishop, everything_else, bishop_queen)
    |> list.fold(0, fn(bits, location) {
      bitboard.bitboard_of(location)
      |> int.bitwise_or(bits)
    })
    |> int.bitwise_and(bishop_queen)
    |> fn(x) { x != 0 }
    |> Ok()
}

fn determine_rook_check(
  table: SlidingDictionary,
  board_data: Board,
  king_location: Int,
) -> Result(Bool, GenerationError) {
  let rook_queen =
    board_data.pieces.rooks
    |> int.bitwise_or(board_data.pieces.queens)
    |> int.bitwise_and(board.get_opponent_bitboard(board_data))

  let everything_else =
    board_data.pieces.white
    |> int.bitwise_or(board_data.pieces.black)
    //This will cut out the enemy bishops and queens as they exist on the every piece bitboard
    |> int.bitwise_exclusive_or(rook_queen)

  use moves <- result.try(
    dict.get(table, king_location) |> result.replace_error(LocationBeyond64),
  )

  let rook_slides =
    generate_rook_moves([], moves.rook, everything_else, rook_queen)
    |> list.fold(0, fn(bits, location) {
      bitboard.bitboard_of(location)
      |> int.bitwise_or(bits)
    })
    |> int.bitwise_and(rook_queen)
    |> fn(x) { x != 0 }
    |> Ok()
}

fn determine_check() {
  todo
}
