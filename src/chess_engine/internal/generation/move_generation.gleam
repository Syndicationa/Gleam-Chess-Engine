import chess_engine/internal/board/bitboard.{type BitBoard}
import chess_engine/internal/board/board.{
  type Board, type Color, type Piece, Bishop, Black, Both, King, KingSide,
  Knight, NoCastle, Pawn, Queen, QueenSide, Rook, White,
}
import chess_engine/internal/board/move.{type Move, EnPassant, Move}
import chess_engine/internal/generation/create_moves
import chess_engine/internal/generation/move_dictionary.{
  type BishopMove, type MoveDictionary, type RookMove,
}
import chess_engine/internal/helper
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result

type GenerationError {
  LocationBeyond64
  InvalidPieceType(Piece)
}

fn shift(number: Int, shift: Int) {
  case shift {
    _ if shift > 0 -> int.bitwise_shift_left(number, shift)
    _ -> int.bitwise_shift_right(number, -shift)
  }
}

fn or_shift(number: Int, amount: Int) {
  int.bitwise_or(number, shift(number, amount))
}

// #region Bitboard Generation
// #region Sliding Bitboards
fn generate_slides(
  bitboard bitboard: Int,
  direction direction: Int,
  friendly friendly: BitBoard,
  enemy enemy: BitBoard,
) -> BitBoard {
  int.bitwise_or(friendly, enemy)
  |> int.bitwise_and(bitboard)
  |> shift(direction)
  |> int.bitwise_and(bitboard)
  |> or_shift(direction)
  |> or_shift(direction * 2)
  |> or_shift(direction * 3)
  |> int.bitwise_and(bitboard)
  |> int.bitwise_exclusive_or(bitboard)
}

// #region Single Direction slides
fn generate_rook_vertical(
  rook: RookMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> BitBoard {
  generate_slides(rook.up, 8, friendly, enemy)
  |> int.bitwise_or(generate_slides(rook.down, -8, friendly, enemy))
}

fn generate_rook_horizontal(
  rook: RookMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> BitBoard {
  generate_slides(rook.left, -1, friendly, enemy)
  |> int.bitwise_or(generate_slides(rook.right, 1, friendly, enemy))
}

fn generate_bishop_uldr(
  bishop: BishopMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> BitBoard {
  generate_slides(bishop.up_left, 7, friendly, enemy)
  |> int.bitwise_or(generate_slides(bishop.down_right, -7, friendly, enemy))
}

fn generate_bishop_dlur(
  bishop: BishopMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> BitBoard {
  generate_slides(bishop.up_right, 9, friendly, enemy)
  |> int.bitwise_or(generate_slides(bishop.down_left, -9, friendly, enemy))
}

// #endregion

fn generate_rook_moves(
  rook: RookMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> BitBoard {
  generate_slides(rook.up, 8, friendly, enemy)
  |> int.bitwise_or(generate_slides(rook.down, -8, friendly, enemy))
  |> int.bitwise_or(generate_slides(rook.left, -1, friendly, enemy))
  |> int.bitwise_or(generate_slides(rook.right, 1, friendly, enemy))
}

fn generate_bishop_moves(
  bishop: BishopMove,
  friendly: BitBoard,
  enemy: BitBoard,
) -> BitBoard {
  generate_slides(bishop.up_right, 9, friendly, enemy)
  |> int.bitwise_or(generate_slides(bishop.up_left, 7, friendly, enemy))
  |> int.bitwise_or(generate_slides(bishop.down_right, -7, friendly, enemy))
  |> int.bitwise_or(generate_slides(bishop.down_left, -9, friendly, enemy))
}

fn generate_sliding_move(
  dictionary table: MoveDictionary,
  piece piece: Piece,
  location location: Int,
  friendly friendly: BitBoard,
  enemy enemy: BitBoard,
) -> Result(BitBoard, GenerationError) {
  use moves <- result.try(
    dict.get(table, location) |> result.replace_error(LocationBeyond64),
  )

  case piece {
    Queen ->
      generate_rook_moves(moves.rook, friendly, enemy)
      |> int.bitwise_or(generate_bishop_moves(moves.bishop, friendly, enemy))
      |> Ok()
    Rook -> Ok(generate_rook_moves(moves.rook, friendly, enemy))
    Bishop -> Ok(generate_bishop_moves(moves.bishop, friendly, enemy))
    piece -> Error(InvalidPieceType(piece))
  }
}

//#endregion

fn generate_castles(
  color: Color,
  board_data: Board,
  attack_mask: BitBoard,
) -> BitBoard {
  let shift_value = case color {
    White -> 0
    Black -> 56
  }

  let queen_side_attack = int.bitwise_shift_left(0b00001100, shift_value)
  let queen_side_intercept = int.bitwise_shift_left(0b00001110, shift_value)
  let king_side = int.bitwise_shift_left(0b01100000, shift_value)

  let pieces_bitboard =
    int.bitwise_or(board_data.pieces.white, board_data.pieces.black)

  let all_bitboard =
    pieces_bitboard
    //This ensures that the player can't castle through check
    |> int.bitwise_or(attack_mask)

  let can_king_side = int.bitwise_and(king_side, all_bitboard) == 0
  let can_queen_side =
    int.bitwise_and(queen_side_attack, attack_mask) == 0
    && int.bitwise_and(queen_side_intercept, pieces_bitboard) == 0

  case board.get_player_castling(board_data) {
    NoCastle -> 0
    Both if can_king_side && can_queen_side ->
      int.bitwise_shift_left(0b1000100, shift_value)
    Both | KingSide if can_king_side ->
      int.bitwise_shift_left(0b1000000, shift_value)
    Both | QueenSide if can_queen_side ->
      int.bitwise_shift_left(0b0000100, shift_value)
    _ -> 0
  }
}

//#region Pawn Bitboards

///Generates pawn moves from the pawn's location, it's color, the friendly and enemy bitboards.
///En passant will be handled with its own function
fn generate_pawn_moves(
  location: Int,
  direction: Color,
  friendly: BitBoard,
  enemy: BitBoard,
) {
  let rank = int.bitwise_shift_right(location, 3)

  let #(direction_int, on_starting_rank) = case direction {
    White -> #(0o1_0, 1 == rank)
    Black -> #(-{ 0o1_0 }, 6 == rank)
  }

  let blocking_bitboard = int.bitwise_or(friendly, enemy)

  let rank_bitboard =
    int.bitwise_shift_left(
      0xff,
      int.bitwise_shift_left(rank, 3) + direction_int,
    )

  let move_square =
    bitboard.bitboard_of(location + direction_int)
    |> bitboard.nimply(blocking_bitboard)

  let two_move_forward =
    helper.ternary(on_starting_rank, move_square, 0)
    |> int.bitwise_shift_left(direction_int)
    |> bitboard.nimply(blocking_bitboard)

  let attack_squares =
    shift(0b101, location + direction_int - 1)
    |> int.bitwise_and(rank_bitboard)
    |> int.bitwise_and(enemy)

  move_square
  |> int.bitwise_or(two_move_forward)
  |> int.bitwise_or(attack_squares)
}

fn generate_pawns_to(board_data: Board, location: Int) -> BitBoard {
  //If location has enemy piece, then generate attack pair
  //otherwise generate normal and if location is on the 4 or 5 (W or B) ranks then generate the 2 move[if the 1 square isn't occupied]

  let enemy_board = board.get_opponent_bitboard(board_data)

  use <- bool.guard(
    bitboard.is_on_bitboard(enemy_board, at: location),
    generate_pawn_attack_squares(
      location,
      board.opposite_color(board_data.active_color),
    ),
  )

  let occupied_board =
    board.get_player_bitboard(board_data) |> int.bitwise_or(enemy_board)

  let rank = int.bitwise_shift_right(location, 3)

  let #(direction_int, could_be_on_starting_rank) = case
    board_data.active_color
  {
    White -> #(-{ 0o1_0 }, 3 == rank)
    Black -> #(0o1_0, 4 == rank)
  }

  use <- bool.guard(
    bitboard.is_on_bitboard(occupied_board, at: location + direction_int),
    bitboard.bitboard_of(location + direction_int),
  )

  use <- bool.guard(
    could_be_on_starting_rank,
    bitboard.bitboard_of(location + direction_int * 2),
  )

  0
}

///This is to be used for the generation of the enemy attacking bitboard
fn generate_pawn_attack_squares(location: Int, direction: Color) {
  let rank = int.bitwise_and(location, 0b111000)

  let direction_int = case direction {
    White -> 0o1_0
    Black -> -{ 0o1_0 }
  }

  let rank_bitboard = int.bitwise_shift_left(0xff, rank + direction_int)

  shift(0b101, location + direction_int - 1)
  |> int.bitwise_and(rank_bitboard)
}

fn add_en_passant(
  dictionary: MoveDictionary,
  move_accumulator: List(Move),
  board_data: Board,
  start: Int,
  destination: Int,
) -> List(Move) {
  let move = Move(Pawn, start, destination, EnPassant)

  let result_board = move.run_en_passant(board_data, move)

  use <- bool.guard(in_check(dictionary, result_board), move_accumulator)

  list.prepend(move_accumulator, move)
}

fn generate_en_passants(
  move_accumulator: List(Move),
  dictionary: MoveDictionary,
  board_data: Board,
) -> List(Move) {
  case board_data.en_passant_square {
    None -> move_accumulator
    Some(idx) -> {
      let en_passanters =
        generate_pawn_attack_squares(
          idx,
          board.opposite_color(board_data.active_color),
        )
        |> int.bitwise_and(board_data.pieces.pawns)
        |> int.bitwise_and(board.get_player_bitboard(board_data))
      use <- bool.guard(en_passanters == 0, move_accumulator)

      bitboard.fold(en_passanters, move_accumulator, fn(acc, start_idx) {
        add_en_passant(dictionary, acc, board_data, start_idx, idx)
      })
    }
  }
}

fn en_passant_to(
  move_accumulator: List(Move),
  dictionary: MoveDictionary,
  board_data: Board,
  square_to: Int,
) -> List(Move) {
  use <- bool.guard(
    Some(square_to) != board_data.en_passant_square,
    move_accumulator,
  )
  generate_en_passants(move_accumulator, dictionary, board_data)
}

//#endregion
//#endregion

type AttackBitboards {
  AttackBitboards(
    king: BitBoard,
    rook_ud: BitBoard,
    rook_lr: BitBoard,
    bishop_uldr: BitBoard,
    bishop_dlur: BitBoard,
    knight: BitBoard,
    pawn: BitBoard,
  )
}

type PinMask {
  PinMask(
    uldr: BitBoard,
    dlur: BitBoard,
    ud: BitBoard,
    lr: BitBoard,
    empty_ud: BitBoard,
    empty_lr: BitBoard,
    empty_uldr: BitBoard,
    empty_dlur: BitBoard,
  )
}

type CheckPiece {
  UpDownSlide
  LeftRightSlide
  ULDRSlide
  DLURSlide
  KnightJump
  PawnAttack
}

type CheckType {
  NoCheck
  Single(CheckPiece)
  Double
}

fn generate_attack_bitboard(
  dictionary: MoveDictionary,
  board_data: Board,
  color: Color,
) {
  let attacker_bitboard = board.get_color_bitboard(board_data, color)

  let pawns = int.bitwise_and(attacker_bitboard, board_data.pieces.pawns)
  let knights = int.bitwise_and(attacker_bitboard, board_data.pieces.knights)
  let bishops = int.bitwise_and(attacker_bitboard, board_data.pieces.bishops)
  let rooks = int.bitwise_and(attacker_bitboard, board_data.pieces.rooks)
  let queens = int.bitwise_and(attacker_bitboard, board_data.pieces.queens)
  let kings = int.bitwise_and(attacker_bitboard, board_data.pieces.kings)

  let defender_bitboard =
    board.opposite_color(color)
    |> board.get_color_bitboard(board_data, _)
    |> bitboard.nimply(board_data.pieces.kings)

  let pawn =
    bitboard.fold(pawns, 0, fn(acc, idx) {
      int.bitwise_or(acc, generate_pawn_attack_squares(idx, color))
    })
  let knight =
    bitboard.fold(knights, 0, fn(acc, idx) {
      dict.get(dictionary, idx)
      |> result.map(fn(moves) { moves.knight })
      |> result.unwrap(0)
      |> int.bitwise_or(acc)
    })
  let #(bishop_uldr, bishop_dlur) =
    int.bitwise_or(queens, bishops)
    |> bitboard.fold(#(0, 0), fn(acc, idx) {
      let #(uldr, dlur) = acc

      dict.get(dictionary, idx)
      |> result.map(fn(moves) {
        #(
          int.bitwise_or(
            uldr,
            generate_bishop_uldr(
              moves.bishop,
              attacker_bitboard,
              defender_bitboard,
            ),
          ),
          int.bitwise_or(
            dlur,
            generate_bishop_dlur(
              moves.bishop,
              attacker_bitboard,
              defender_bitboard,
            ),
          ),
        )
      })
      |> result.unwrap(acc)
    })
  let #(rook_ud, rook_lr) =
    int.bitwise_or(queens, rooks)
    |> bitboard.fold(#(0, 0), fn(acc, idx) {
      let #(ud, lr) = acc

      dict.get(dictionary, idx)
      |> result.map(fn(moves) {
        #(
          int.bitwise_or(
            ud,
            generate_rook_vertical(
              moves.rook,
              attacker_bitboard,
              defender_bitboard,
            ),
          ),
          int.bitwise_or(
            lr,
            generate_rook_horizontal(
              moves.rook,
              attacker_bitboard,
              defender_bitboard,
            ),
          ),
        )
      })
      |> result.unwrap(acc)
    })

  let king =
    bitboard.fold(kings, 0, fn(acc, idx) {
      dict.get(dictionary, idx)
      |> result.map(fn(moves) { moves.king })
      |> result.unwrap(0)
      |> int.bitwise_or(acc)
    })

  AttackBitboards(
    king:,
    rook_ud:,
    rook_lr:,
    bishop_uldr:,
    bishop_dlur:,
    knight:,
    pawn:,
  )
}

fn detect_check(attacks: AttackBitboards, board_data: Board, color: Color) {
  let active_king =
    board.get_color_bitboard(board_data, color)
    |> int.bitwise_and(board_data.pieces.kings)

  let ud_check = case int.bitwise_and(active_king, attacks.rook_ud) {
    0 -> 0
    _ -> 32
  }

  let lr_check = case int.bitwise_and(active_king, attacks.rook_lr) {
    0 -> 0
    _ -> 16
  }

  let uldr_check = case int.bitwise_and(active_king, attacks.bishop_uldr) {
    0 -> 0
    _ -> 8
  }

  let dlur_check = case int.bitwise_and(active_king, attacks.bishop_dlur) {
    0 -> 0
    _ -> 4
  }

  let knight_check = case int.bitwise_and(active_king, attacks.knight) {
    0 -> 0
    _ -> 2
  }

  let pawn_check = case int.bitwise_and(active_king, attacks.pawn) {
    0 -> 0
    _ -> 1
  }

  let check =
    ud_check + lr_check + uldr_check + dlur_check + knight_check + pawn_check

  case Nil {
    _ if check == 0 -> NoCheck
    _ if pawn_check == 1 -> Single(PawnAttack)
    _ if knight_check == 2 -> Single(KnightJump)
    _ if dlur_check == 4 -> Single(DLURSlide)
    _ if uldr_check == 8 -> Single(ULDRSlide)
    _ if lr_check == 16 -> Single(LeftRightSlide)
    _ if ud_check == 32 -> Single(UpDownSlide)
    _ -> Double
  }
}

fn total_attack_bitboard(attacks: AttackBitboards) -> BitBoard {
  attacks.king
  |> int.bitwise_or(attacks.rook_ud)
  |> int.bitwise_or(attacks.rook_lr)
  |> int.bitwise_or(attacks.bishop_uldr)
  |> int.bitwise_or(attacks.bishop_dlur)
  |> int.bitwise_or(attacks.knight)
  |> int.bitwise_or(attacks.pawn)
}

pub fn in_check(dictionary: MoveDictionary, board_data: Board) -> Bool {
  board.opposite_color(board_data.active_color)
  |> generate_attack_bitboard(dictionary, board_data, _)
  |> detect_check(board_data, board_data.active_color)
  |> fn(x) { x != NoCheck }
}

fn generate_pin_mask(
  dictionary: MoveDictionary,
  board_data: Board,
  king_location: Int,
  attacks: AttackBitboards,
) -> Result(PinMask, Nil) {
  let player_bitboard = board.get_player_bitboard(board_data)
  let enemy_bitboard = board.get_opponent_bitboard(board_data)

  use move_entry <- result.try(dict.get(dictionary, king_location))

  let left_right =
    generate_rook_horizontal(move_entry.rook, player_bitboard, enemy_bitboard)
    |> int.bitwise_and(attacks.rook_lr)
    |> int.bitwise_and(player_bitboard)

  let up_down =
    generate_rook_vertical(move_entry.rook, player_bitboard, enemy_bitboard)
    |> int.bitwise_and(attacks.rook_ud)
    |> int.bitwise_and(player_bitboard)

  let uldr =
    generate_bishop_uldr(move_entry.bishop, player_bitboard, enemy_bitboard)
    |> int.bitwise_and(attacks.bishop_uldr)
    |> int.bitwise_and(player_bitboard)

  let dlur =
    generate_bishop_dlur(move_entry.bishop, player_bitboard, enemy_bitboard)
    |> int.bitwise_and(attacks.bishop_dlur)
    |> int.bitwise_and(player_bitboard)

  PinMask(
    uldr:,
    dlur:,
    ud: up_down,
    lr: left_right,
    empty_ud: int.bitwise_or(move_entry.rook.up, move_entry.rook.down),
    empty_lr: int.bitwise_or(move_entry.rook.left, move_entry.rook.right),
    empty_uldr: int.bitwise_or(
      move_entry.bishop.up_left,
      move_entry.bishop.down_right,
    ),
    empty_dlur: int.bitwise_or(
      move_entry.bishop.down_left,
      move_entry.bishop.up_right,
    ),
  )
  |> Ok()
}

fn total_pin_mask(pin_mask: PinMask) -> BitBoard {
  pin_mask.ud
  |> int.bitwise_or(pin_mask.lr)
  |> int.bitwise_or(pin_mask.uldr)
  |> int.bitwise_or(pin_mask.dlur)
}

fn legal_king_slide_moves(
  dictionary: MoveDictionary,
  board_data: Board,
  king_location: Int,
  attack_mask: BitBoard,
) -> List(Move) {
  dict.get(dictionary, king_location)
  |> result.map(fn(x) { x.king })
  |> result.unwrap(0)
  |> bitboard.nimply(attack_mask)
  |> create_moves.create_moves_from_bitboard(
    [],
    board_data,
    King,
    king_location,
    _,
  )
}

fn generate_castle_moves(
  move_accumulator: List(Move),
  board_data: Board,
  king_location: Int,
  attack_mask: BitBoard,
) -> List(Move) {
  generate_castles(board_data.active_color, board_data, attack_mask)
  |> create_moves.create_moves_from_bitboard(
    move_accumulator,
    board_data,
    King,
    king_location,
    _,
  )
}

fn generate_moves_to_location(
  move_accumulator: List(Move),
  dictionary: MoveDictionary,
  board_data: Board,
  location: Int,
  pin_mask: PinMask,
) -> Result(List(Move), List(Move)) {
  let player_bitboard = board.get_player_bitboard(board_data)
  let enemy_bitboard = board.get_opponent_bitboard(board_data)
  use <- bool.guard(
    bitboard.is_on_bitboard(player_bitboard, location),
    Ok(move_accumulator),
  )

  use dictionary_entry <- result.try(
    dict.get(dictionary, location) |> result.replace_error(move_accumulator),
  )

  let pinned_mask = total_pin_mask(pin_mask)

  let pawns =
    generate_pawns_to(board_data, location)
    |> int.bitwise_and(player_bitboard)
    |> int.bitwise_and(board_data.pieces.pawns)
    |> bitboard.nimply(pinned_mask)

  let knights =
    dictionary_entry.knight
    |> int.bitwise_and(player_bitboard)
    |> int.bitwise_and(board_data.pieces.knights)
    |> bitboard.nimply(pinned_mask)

  let bishops =
    generate_bishop_moves(
      dictionary_entry.bishop,
      player_bitboard,
      enemy_bitboard,
    )
    |> int.bitwise_and(player_bitboard)
    |> int.bitwise_and(board_data.pieces.bishops)
    |> bitboard.nimply(pinned_mask)

  let rooks =
    generate_rook_moves(dictionary_entry.rook, player_bitboard, enemy_bitboard)
    |> int.bitwise_and(player_bitboard)
    |> int.bitwise_and(board_data.pieces.rooks)
    |> bitboard.nimply(pinned_mask)

  let queens =
    generate_bishop_moves(
      dictionary_entry.bishop,
      player_bitboard,
      enemy_bitboard,
    )
    |> int.bitwise_or(generate_rook_moves(
      dictionary_entry.rook,
      player_bitboard,
      enemy_bitboard,
    ))
    |> int.bitwise_and(player_bitboard)
    |> int.bitwise_and(board_data.pieces.queens)
    |> bitboard.nimply(pinned_mask)

  create_moves.create_moves_to_location(
    move_accumulator,
    board_data,
    Pawn,
    pawns,
    location,
  )
  |> en_passant_to(dictionary, board_data, location)
  |> create_moves.create_moves_to_location(
    board_data,
    Knight,
    knights,
    location,
  )
  |> create_moves.create_moves_to_location(
    board_data,
    Bishop,
    bishops,
    location,
  )
  |> create_moves.create_moves_to_location(board_data, Rook, rooks, location)
  |> create_moves.create_moves_to_location(board_data, Queen, queens, location)
  |> Ok()
}

fn generate_sliding_check_responses(
  move_accumulator: List(Move),
  dictionary: MoveDictionary,
  board_data: Board,
  enemy_attacks: AttackBitboards,
  king_location: Int,
  pinned_mask: PinMask,
  sliding_attack: CheckPiece,
) -> List(Move) {
  let player_board = board.get_player_bitboard(board_data)
  let enemy_board = board.get_opponent_bitboard(board_data)

  let #(enemy_attack, primary_piece_board, king_piece) = case sliding_attack {
    UpDownSlide -> #(enemy_attacks.rook_ud, board_data.pieces.rooks, Rook)
    LeftRightSlide -> #(enemy_attacks.rook_lr, board_data.pieces.rooks, Rook)
    ULDRSlide -> #(enemy_attacks.bishop_uldr, board_data.pieces.bishops, Bishop)
    DLURSlide -> #(enemy_attacks.bishop_dlur, board_data.pieces.bishops, Bishop)
    _ -> #(0, 0, Queen)
  }

  let king_attack =
    generate_sliding_move(
      dictionary,
      king_piece,
      king_location,
      player_board,
      enemy_board,
    )
    |> result.unwrap(0)

  let attacking_ray = int.bitwise_and(king_attack, enemy_attack)

  let checking_piece =
    primary_piece_board
    //Add queens to the primary type
    |> int.bitwise_or(board_data.pieces.queens)
    //Relevant enemy pieces
    |> int.bitwise_and(enemy_board)
    //Gets those attacking the king
    |> int.bitwise_and(king_attack)

  let block_ray =
    generate_sliding_move(
      dictionary,
      Queen,
      bitboard.get_index(checking_piece),
      enemy_board,
      player_board,
    )
    |> result.unwrap(0)
    |> int.bitwise_and(attacking_ray)

  int.bitwise_or(block_ray, checking_piece)
  |> bitboard.fold(move_accumulator, fn(acc, idx) {
    generate_moves_to_location(acc, dictionary, board_data, idx, pinned_mask)
    |> result.unwrap_both()
  })
}

fn generate_move_for_pinnable_piece(
  dictionary: MoveDictionary,
  board_data: Board,
) {
  let player_board = board.get_player_bitboard(board_data)
  let enemy_board = board.get_opponent_bitboard(board_data)

  fn(pin_ray: BitBoard) {
    fn(move_accumulator: List(Move), piece_location: Int) -> List(Move) {
      let piece_type =
        piece_location
        |> board.get_piece_at_location(board_data, _)

      case piece_type {
        None | Some(Knight) | Some(King) -> move_accumulator
        Some(Pawn) ->
          generate_pawn_moves(
            piece_location,
            board_data.active_color,
            player_board,
            enemy_board,
          )
          |> int.bitwise_and(pin_ray)
          |> create_moves.create_moves_from_bitboard(
            move_accumulator,
            board_data,
            Pawn,
            piece_location,
            _,
          )
        Some(slider) ->
          generate_sliding_move(
            dictionary,
            slider,
            piece_location,
            player_board,
            enemy_board,
          )
          |> result.unwrap(0)
          |> int.bitwise_and(pin_ray)
          |> create_moves.create_moves_from_bitboard(
            move_accumulator,
            board_data,
            slider,
            piece_location,
            _,
          )
      }
    }
  }
}

fn generate_pin_moves(
  move_accumulator: List(Move),
  dictionary: MoveDictionary,
  board_data: Board,
  pin_mask: PinMask,
) -> List(Move) {
  let player_board = board.get_player_bitboard(board_data)

  let orthogonal_sliders =
    int.bitwise_or(board_data.pieces.queens, board_data.pieces.rooks)
    |> int.bitwise_or(board_data.pieces.pawns)
    |> int.bitwise_and(player_board)

  let diagonal_sliders =
    int.bitwise_or(board_data.pieces.queens, board_data.pieces.bishops)
    |> int.bitwise_or(board_data.pieces.pawns)
    |> int.bitwise_and(player_board)

  let pin_move_generator =
    generate_move_for_pinnable_piece(dictionary, board_data)

  let ud_moves =
    pin_mask.ud
    |> int.bitwise_and(orthogonal_sliders)
    |> bitboard.fold(move_accumulator, pin_move_generator(pin_mask.empty_ud))

  let lr_moves =
    pin_mask.lr
    |> int.bitwise_and(orthogonal_sliders)
    |> bitboard.fold(ud_moves, pin_move_generator(pin_mask.empty_lr))

  let uldr_moves =
    pin_mask.uldr
    |> int.bitwise_and(diagonal_sliders)
    |> bitboard.fold(lr_moves, pin_move_generator(pin_mask.empty_uldr))

  pin_mask.dlur
  |> int.bitwise_and(diagonal_sliders)
  |> bitboard.fold(uldr_moves, pin_move_generator(pin_mask.empty_dlur))
}

fn generate_normal_moves(
  move_accumulator: List(Move),
  dictionary: MoveDictionary,
  board_data: Board,
  pin_mask: PinMask,
) -> List(Move) {
  let player_board = board.get_player_bitboard(board_data)
  let enemy_board = board.get_opponent_bitboard(board_data)

  let total_pins = total_pin_mask(pin_mask)

  let pawns =
    int.bitwise_and(player_board, board_data.pieces.pawns)
    |> bitboard.nimply(total_pins)
  let knights =
    int.bitwise_and(player_board, board_data.pieces.knights)
    |> bitboard.nimply(total_pins)
  let bishops =
    int.bitwise_and(player_board, board_data.pieces.bishops)
    |> bitboard.nimply(total_pins)
  let rooks =
    int.bitwise_and(player_board, board_data.pieces.rooks)
    |> bitboard.nimply(total_pins)
  let queens =
    int.bitwise_and(player_board, board_data.pieces.queens)
    |> bitboard.nimply(total_pins)

  bitboard.fold(pawns, move_accumulator, fn(acc, idx) {
    generate_pawn_moves(idx, board_data.active_color, player_board, enemy_board)
    |> create_moves.create_moves_from_bitboard(acc, board_data, Pawn, idx, _)
  })
  |> bitboard.fold(knights, _, fn(acc, idx) {
    dict.get(dictionary, idx)
    |> result.map(fn(x) { x.knight })
    |> result.unwrap(0)
    |> create_moves.create_moves_from_bitboard(acc, board_data, Knight, idx, _)
  })
  |> bitboard.fold(bishops, _, fn(acc, idx) {
    generate_sliding_move(dictionary, Bishop, idx, player_board, enemy_board)
    |> result.unwrap(0)
    |> create_moves.create_moves_from_bitboard(acc, board_data, Bishop, idx, _)
  })
  |> bitboard.fold(rooks, _, fn(acc, idx) {
    generate_sliding_move(dictionary, Rook, idx, player_board, enemy_board)
    |> result.unwrap(0)
    |> create_moves.create_moves_from_bitboard(acc, board_data, Rook, idx, _)
  })
  |> bitboard.fold(queens, _, fn(acc, idx) {
    generate_sliding_move(dictionary, Queen, idx, player_board, enemy_board)
    |> result.unwrap(0)
    |> create_moves.create_moves_from_bitboard(acc, board_data, Queen, idx, _)
  })
}

pub fn get_all_moves(
  dictionary: MoveDictionary,
  board_data: Board,
) -> List(Move) {
  let enemy_attacks =
    board.opposite_color(board_data.active_color)
    |> generate_attack_bitboard(dictionary, board_data, _)

  let attack_mask = total_attack_bitboard(enemy_attacks)

  let king_location =
    board.get_player_bitboard(board_data)
    |> int.bitwise_and(board_data.pieces.kings)
    |> bitboard.get_index()

  let pin_mask =
    generate_pin_mask(dictionary, board_data, king_location, enemy_attacks)
    |> result.unwrap(PinMask(0, 0, 0, 0, 0, 0, 0, 0))

  case detect_check(enemy_attacks, board_data, board_data.active_color) {
    Double ->
      legal_king_slide_moves(dictionary, board_data, king_location, attack_mask)
    Single(KnightJump) -> {
      let target_square =
        dict.get(dictionary, king_location)
        |> result.map(fn(x) { x.knight })
        |> result.unwrap(0)
        |> int.bitwise_and(board.get_opponent_bitboard(board_data))
        |> int.bitwise_and(board_data.pieces.knights)
        |> bitboard.get_index()

      legal_king_slide_moves(dictionary, board_data, king_location, attack_mask)
      |> generate_moves_to_location(
        dictionary,
        board_data,
        target_square,
        pin_mask,
      )
      |> result.unwrap_both()
    }

    Single(PawnAttack) -> {
      let target_square =
        generate_pawn_attack_squares(king_location, board_data.active_color)
        |> int.bitwise_and(board.get_opponent_bitboard(board_data))
        |> int.bitwise_and(board_data.pieces.pawns)
        |> bitboard.get_index()

      legal_king_slide_moves(dictionary, board_data, king_location, attack_mask)
      |> generate_en_passants(dictionary, board_data)
      |> generate_moves_to_location(
        dictionary,
        board_data,
        target_square,
        pin_mask,
      )
      |> result.unwrap_both()
    }

    Single(slider) -> {
      legal_king_slide_moves(dictionary, board_data, king_location, attack_mask)
      |> generate_sliding_check_responses(
        dictionary,
        board_data,
        enemy_attacks,
        king_location,
        pin_mask,
        slider,
      )
    }
    NoCheck -> {
      legal_king_slide_moves(dictionary, board_data, king_location, attack_mask)
      |> generate_castle_moves(board_data, king_location, attack_mask)
      |> generate_pin_moves(dictionary, board_data, pin_mask)
      |> generate_en_passants(dictionary, board_data)
      |> generate_normal_moves(dictionary, board_data, pin_mask)
    }
  }
}
