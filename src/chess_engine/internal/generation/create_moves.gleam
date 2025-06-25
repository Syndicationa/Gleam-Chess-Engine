import chess_engine/internal/board/bitboard.{type BitBoard}
import chess_engine/internal/board/board.{
  type Board, type Piece, Bishop, King, Knight, Pawn, Queen, Rook,
}
import chess_engine/internal/board/move.{
  type Move, Capture, Castle, CastleKingSide, CastleQueenSide, Move, Normal,
  Promotion, PromotionCapture,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

fn create_pawn_move(
  move_accumulator: List(Move),
  start: Int,
  destination: Int,
  captured_piece: Option(Piece),
) -> List(Move) {
  let rank = int.bitwise_shift_right(destination, 3)

  case rank, captured_piece {
    7, Some(piece) | 0, Some(piece) ->
      list.prepend(
        move_accumulator,
        Move(Pawn, start, destination, PromotionCapture(Queen, piece)),
      )
      |> list.prepend(Move(
        Pawn,
        start,
        destination,
        PromotionCapture(Rook, piece),
      ))
      |> list.prepend(Move(
        Pawn,
        start,
        destination,
        PromotionCapture(Bishop, piece),
      ))
      |> list.prepend(Move(
        Pawn,
        start,
        destination,
        PromotionCapture(Knight, piece),
      ))
    7, None | 0, None ->
      list.prepend(
        move_accumulator,
        Move(Pawn, start, destination, Promotion(Queen)),
      )
      |> list.prepend(Move(Pawn, start, destination, Promotion(Rook)))
      |> list.prepend(Move(Pawn, start, destination, Promotion(Bishop)))
      |> list.prepend(Move(Pawn, start, destination, Promotion(Knight)))
    _, Some(piece) ->
      list.prepend(
        move_accumulator,
        Move(Pawn, start, destination, Capture(piece)),
      )
    _, None ->
      list.prepend(move_accumulator, Move(Pawn, start, destination, Normal))
  }
}

pub fn create_moves_from_bitboard(
  move_accumulator: List(Move),
  board_data: Board,
  piece: Piece,
  start: Int,
  destinations: BitBoard,
) -> List(Move) {
  let true_destinations =
    bitboard.not(board.get_player_bitboard(board_data))
    |> int.bitwise_and(destinations)

  bitboard.fold(true_destinations, move_accumulator, fn(acc, destination) {
    let captured_piece = board.get_piece_at_location(board_data, destination)
    case piece, captured_piece {
      Pawn, captured -> create_pawn_move(acc, start, destination, captured)
      King, None if start - destination == 2 ->
        list.prepend(
          acc,
          Move(piece, start, destination, Castle(CastleQueenSide)),
        )
      King, None if start - destination == -2 ->
        list.prepend(
          acc,
          Move(piece, start, destination, Castle(CastleKingSide)),
        )
      piece, None -> list.prepend(acc, Move(piece, start, destination, Normal))
      piece, Some(target) ->
        list.prepend(acc, Move(piece, start, destination, Capture(target)))
    }
  })
}

pub fn create_moves_to_location(
  move_accumulator: List(Move),
  board_data: Board,
  piece: Piece,
  starts starting_squares: BitBoard,
  final destination: Int,
) -> List(Move) {
  bitboard.fold(starting_squares, move_accumulator, fn(acc, start) {
    let captured_piece = board.get_piece_at_location(board_data, destination)
    case piece, captured_piece {
      Pawn, captured -> create_pawn_move(acc, start, destination, captured)
      piece, None -> list.prepend(acc, Move(piece, start, destination, Normal))
      piece, Some(target) ->
        list.prepend(acc, Move(piece, start, destination, Capture(target)))
    }
  })
}
