import chess_engine/internal/board/bitboard.{type BitBoard}
import chess_engine/internal/board/board.{
  type Board, type CastleState, type Color, type Piece, Bishop, Black, Both,
  King, KingSide, Knight, NoCastle, Pawn, Queen, QueenSide, Rook, White,
}
import chess_engine/internal/board/move.{
  type Move, Capture, Castle, CastleKingSide, CastleQueenSide, EnPassant, Move,
  Normal, Promotion, PromotionCapture,
}
import chess_engine/internal/generation/move_dictionary.{
  type BishopMove, type MoveDictionary, type RookMove,
}
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

fn fast_bit_length(number: Int, count: Int) -> Int {
  case number {
    0b0 -> 0 + count
    0b1 -> 1 + count
    0b10 -> 2 + count
    0b100 -> 3 + count
    0b1000 -> 4 + count
    0b10000 -> 5 + count
    0b100000 -> 6 + count
    0b1000000 -> 7 + count
    0b10000000 -> 8 + count
    num if num >= 0b1_0000_0000_0000_0000_0000_0000_0000_0000 ->
      int.bitwise_shift_right(num, 32)
      |> fast_bit_length(count + 32)
    num if num >= 0b1_0000_0000_0000_0000 ->
      int.bitwise_shift_right(num, 16)
      |> fast_bit_length(count + 16)
    num if num >= 0b1_0000_0000 ->
      int.bitwise_shift_right(num, 8)
      |> fast_bit_length(count + 8)
    num ->
      int.bitwise_shift_right(num, 1)
      |> fast_bit_length(count + 1)
  }
}

///This should require only about 3 or 4 calls to fast_bit_length
fn bit_length(number: Int) -> Int {
  fast_bit_length(number, 0)
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
    bitboard.isolate_lsb(complete)
    |> bit_length()
    |> int.subtract(1)

  list.take(square_list, count)
}

pub type GenerationError {
  LocationBeyond64
  InvalidPieceType(Piece)
  UnknownCheck
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
  table: MoveDictionary,
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

///Taking in the list of moves and the friendly BitBoard, it filters all the 
fn generate_moves_from_list(
  move_list: List(Int),
  friendly: BitBoard,
) -> List(Int) {
  move_list
  |> list.filter(fn(location) {
    bitboard.is_on_bitboard(friendly, location)
    |> bool.negate()
  })
}

fn generate_castles(
  color: Color,
  all_bitboard: Int,
  player_castle_state: CastleState,
) {
  let queen_side = 0b00001110
  let king_side = 0b01100000

  let shift_value = case color {
    White -> 0
    Black -> 56
  }

  let all_bitboard = int.bitwise_shift_right(all_bitboard, shift_value)

  let can_king_side = int.bitwise_and(king_side, all_bitboard) == 0
  let can_queen_side = int.bitwise_and(queen_side, all_bitboard) == 0

  case player_castle_state {
    NoCastle -> []
    Both if can_king_side && can_queen_side -> [
      2 + shift_value,
      6 + shift_value,
    ]
    Both | KingSide if can_king_side -> [6 + shift_value]
    Both | QueenSide if can_queen_side -> [2 + shift_value]
    _ -> []
  }
}

///Generates pawn moves from the pawn's location, it's color, the friendly and enemy bitboards, and the en passant square
fn generate_pawn_moves(
  location: Int,
  direction: Color,
  friendly: BitBoard,
  enemy: BitBoard,
  en_passant_square: Option(Int),
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
    |> bool.or(en_passant_square == Some(attack_left))
    |> bool.and(file > 0)

  let can_attack_right =
    enemy
    |> bitboard.value_on_bitboard(attack_right)
    |> fn(x) { x == 1 }
    |> bool.or(en_passant_square == Some(attack_right))
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
  let distance = int.absolute_value(destination - start)

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
    5, None | 2, None if distance != 8 -> [
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
      Move(piece, start, destination, Castle(CastleQueenSide)),
    ]
    King, None if start - destination == -2 -> [
      Move(piece, start, destination, Castle(CastleKingSide)),
    ]
    piece, None -> [Move(piece, start, destination, Normal)]
    piece, Some(target) -> [Move(piece, start, destination, Capture(target))]
  }
}

fn determine_pawn_check(
  king_location: Int,
  board_data: Board,
  color: Color,
) -> Bool {
  let file = int.bitwise_and(king_location, 7)
  let enemy =
    board.get_opponent_color_bitboard(board_data, color)
    |> int.bitwise_and(board_data.pieces.pawns)

  let direction_int = case color {
    White -> 0o1_0
    //I want this to be a negative octal
    Black -> -8
  }

  let forward_square = king_location + direction_int
  let attack_left = forward_square - 1
  let attack_right = forward_square + 1

  let can_attack_left =
    enemy
    |> bitboard.value_on_bitboard(attack_left)
    |> fn(x) { x == 1 }
    |> bool.and(file > 0)

  let can_attack_right =
    enemy
    |> bitboard.value_on_bitboard(attack_right)
    |> fn(x) { x == 1 }
    |> bool.and(file < 7)

  can_attack_left || can_attack_right
}

fn determine_king_check(
  king_moves: List(Int),
  board_data: Board,
  color: Color,
) -> Bool {
  board.get_opponent_color_bitboard(board_data, color)
  |> int.bitwise_and(board_data.pieces.kings)
  //This will generate a bitboard of all non-enemy king squares
  |> bitboard.not()
  |> generate_moves_from_list(king_moves, _)
  |> fn(x) {
    case x {
      //If there are no enemy kings a king move away, then we cannot be in check
      [] -> False
      _ -> True
    }
  }
}

fn determine_knight_check(
  knight_moves: List(Int),
  board_data: Board,
  color: Color,
) -> Bool {
  board.get_opponent_color_bitboard(board_data, color)
  |> int.bitwise_and(board_data.pieces.knights)
  //This will generate a bitboard of all non-enemy knight squares
  |> bitboard.not()
  |> generate_moves_from_list(knight_moves, _)
  |> fn(x) {
    case x {
      //If there are no enemy knights a knight move away, then we cannot be in check
      [] -> False
      _ -> True
    }
  }
}

fn determine_bishop_check(
  bishop_moves: BishopMove,
  board_data: Board,
  color: Color,
) -> Bool {
  let bishop_queen =
    board_data.pieces.bishops
    |> int.bitwise_or(board_data.pieces.queens)
    |> int.bitwise_and(board.get_opponent_color_bitboard(board_data, color))

  let everything_else =
    board_data.pieces.white
    |> int.bitwise_or(board_data.pieces.black)
    //This will cut out the enemy bishops and queens as they exist on the every piece bitboard
    |> int.bitwise_exclusive_or(bishop_queen)

  generate_bishop_moves([], bishop_moves, everything_else, bishop_queen)
  |> bitboard.generate_bitboard()
  |> int.bitwise_and(bishop_queen)
  |> fn(x) { x != 0 }
}

fn determine_rook_check(
  rook_moves: RookMove,
  board_data: Board,
  color: Color,
) -> Bool {
  let rook_queen =
    board_data.pieces.rooks
    |> int.bitwise_or(board_data.pieces.queens)
    |> int.bitwise_and(board.get_opponent_color_bitboard(board_data, color))

  let everything_else =
    board_data.pieces.white
    |> int.bitwise_or(board_data.pieces.black)
    //This will cut out the enemy rooks and queens as they exist on the every piece bitboard
    |> int.bitwise_exclusive_or(rook_queen)

  generate_rook_moves([], rook_moves, everything_else, rook_queen)
  |> bitboard.generate_bitboard()
  |> int.bitwise_and(rook_queen)
  |> fn(x) { x != 0 }
}

type CheckType {
  NoCheck
  Single(Piece)
  Double
}

fn determine_check(
  table: MoveDictionary,
  board_data: Board,
  king_location: Int,
  color: Color,
) -> Result(CheckType, GenerationError) {
  use moves <- result.try(
    dict.get(table, king_location) |> result.replace_error(LocationBeyond64),
  )

  let king_check = case determine_king_check(moves.king, board_data, color) {
    True -> 16
    False -> 0
  }
  let rook_check = case determine_rook_check(moves.rook, board_data, color) {
    True -> 8
    False -> 0
  }
  let bishop_check = case
    determine_bishop_check(moves.bishop, board_data, color)
  {
    True -> 4
    False -> 0
  }
  let knight_check = case
    determine_knight_check(moves.knight, board_data, color)
  {
    True -> 2
    False -> 0
  }
  let pawn_check = case determine_pawn_check(king_location, board_data, color) {
    True -> 1
    False -> 0
  }

  let check = king_check + rook_check + bishop_check + knight_check + pawn_check
  let is_not_single_check = int.bitwise_and(check, check - 1) != 0

  case is_not_single_check {
    _ if check == 0 -> Ok(NoCheck)
    _ if is_not_single_check -> Ok(Double)
    _ if pawn_check == 1 -> Ok(Single(Pawn))
    _ if knight_check == 2 -> Ok(Single(Knight))
    _ if bishop_check == 4 -> Ok(Single(Bishop))
    _ if rook_check == 8 -> Ok(Single(Rook))
    _ if king_check == 16 -> Ok(Single(King))
    _ -> Error(UnknownCheck)
  }
}

pub fn in_check(table: MoveDictionary, board_data: Board, color: Color) -> Bool {
  case color {
    White -> board_data.pieces.white
    Black -> board_data.pieces.black
  }
  |> int.bitwise_and(board_data.pieces.kings)
  |> bit_length()
  |> determine_check(table, board_data, _, color)
  |> fn(check) { check != Ok(NoCheck) }
}

pub fn pseudo_legal_pawn_moves(
  board_data: Board,
  pawn_bitboard: BitBoard,
  move_list: List(Move),
) -> List(Move) {
  use <- bool.guard(pawn_bitboard == 0, move_list)

  let index =
    bitboard.isolate_lsb(pawn_bitboard) |> bit_length() |> int.subtract(1)

  let pawn_destinations =
    generate_pawn_moves(
      index,
      board_data.active_color,
      board.get_player_bitboard(board_data),
      board.get_opponent_bitboard(board_data),
      board_data.en_passant_square,
    )

  let moves =
    list.flat_map(pawn_destinations, fn(destination) {
      let captured_piece = board.get_piece_at_location(board_data, destination)
      create_move(Pawn, index, destination, captured_piece)
    })

  pseudo_legal_pawn_moves(
    board_data,
    bitboard.remove_from_bitboard(pawn_bitboard, index),
    list.append(moves, move_list),
  )
}

pub fn pseudo_legal_knight_moves(
  table: MoveDictionary,
  board_data: Board,
  knight_bitboard: BitBoard,
  move_list: List(Move),
) -> List(Move) {
  use <- bool.guard(knight_bitboard == 0, move_list)

  let index =
    bitboard.isolate_lsb(knight_bitboard) |> bit_length() |> int.subtract(1)

  let knight_destinations =
    dict.get(table, index)
    |> result.map(fn(x) {
      x.knight
      |> generate_moves_from_list(board.get_player_bitboard(board_data))
    })
    |> result.unwrap([])

  let moves =
    list.flat_map(knight_destinations, fn(destination) {
      let captured_piece = board.get_piece_at_location(board_data, destination)
      create_move(Knight, index, destination, captured_piece)
    })

  pseudo_legal_knight_moves(
    table,
    board_data,
    bitboard.remove_from_bitboard(knight_bitboard, index),
    list.append(moves, move_list),
  )
}

pub fn pseudo_legal_sliding_moves(
  table: MoveDictionary,
  board_data: Board,
  sliding_bitboard: BitBoard,
  piece: Piece,
  move_list: List(Move),
) -> List(Move) {
  use <- bool.guard(sliding_bitboard == 0, move_list)

  let index =
    bitboard.isolate_lsb(sliding_bitboard) |> bit_length() |> int.subtract(1)

  let sliding_destinations =
    generate_sliding_move(
      table,
      piece,
      index,
      board.get_player_bitboard(board_data),
      board.get_opponent_bitboard(board_data),
    )
    |> result.unwrap([])

  let moves =
    list.flat_map(sliding_destinations, fn(destination) {
      let captured_piece = board.get_piece_at_location(board_data, destination)
      create_move(piece, index, destination, captured_piece)
    })

  pseudo_legal_sliding_moves(
    table,
    board_data,
    bitboard.remove_from_bitboard(sliding_bitboard, index),
    piece,
    list.append(moves, move_list),
  )
}

pub fn pseudo_legal_king_moves(
  table: MoveDictionary,
  board_data: Board,
  king_bitboard: BitBoard,
  move_list: List(Move),
) -> List(Move) {
  use <- bool.guard(king_bitboard == 0, move_list)

  let index =
    bitboard.isolate_lsb(king_bitboard)
    |> bit_length()
    |> int.subtract(1)

  let king_destinations =
    dict.get(table, index)
    |> result.map(fn(x) {
      x.king
      |> generate_moves_from_list(board.get_player_bitboard(board_data))
    })
    |> result.unwrap([])
    |> list.append(generate_castles(
      board_data.active_color,
      int.bitwise_or(board_data.pieces.white, board_data.pieces.black),
      board.get_player_castling(board_data),
    ))

  let moves =
    list.flat_map(king_destinations, fn(destination) {
      let captured_piece = board.get_piece_at_location(board_data, destination)
      create_move(King, index, destination, captured_piece)
    })

  pseudo_legal_king_moves(
    table,
    board_data,
    bitboard.remove_from_bitboard(king_bitboard, index),
    list.append(moves, move_list),
  )
}

pub fn pseudo_legal_moves(
  table: MoveDictionary,
  board_data: Board,
) -> List(Move) {
  let player_bitboard = board.get_player_bitboard(board_data)

  let pawns = int.bitwise_and(player_bitboard, board_data.pieces.pawns)
  let knights = int.bitwise_and(player_bitboard, board_data.pieces.knights)
  let bishops = int.bitwise_and(player_bitboard, board_data.pieces.bishops)
  let rooks = int.bitwise_and(player_bitboard, board_data.pieces.rooks)
  let queens = int.bitwise_and(player_bitboard, board_data.pieces.queens)
  let kings = int.bitwise_and(player_bitboard, board_data.pieces.kings)

  pseudo_legal_pawn_moves(board_data, pawns, [])
  |> pseudo_legal_knight_moves(table, board_data, knights, _)
  |> pseudo_legal_sliding_moves(table, board_data, bishops, Bishop, _)
  |> pseudo_legal_sliding_moves(table, board_data, rooks, Rook, _)
  |> pseudo_legal_sliding_moves(table, board_data, queens, Queen, _)
  |> pseudo_legal_king_moves(table, board_data, kings, _)
}

pub fn get_all_moves(table: MoveDictionary, board_data: Board) -> List(Move) {
  pseudo_legal_moves(table, board_data)
  |> list.filter(fn(move_data) {
    let next_board = move.move(board_data, move_data)

    case move_data.data {
      Castle(_) -> list.range(move_data.source, move_data.target)
      _ ->
        next_board.pieces.kings
        |> int.bitwise_and(board.get_color_bitboard(
          next_board,
          board_data.active_color,
        ))
        |> bitboard.isolate_lsb()
        |> bit_length()
        |> int.subtract(1)
        |> list.wrap()
    }
    |> list.all(fn(location) {
      determine_check(table, next_board, location, board_data.active_color)
      |> fn(x) { x == Ok(NoCheck) }
    })
  })
}
