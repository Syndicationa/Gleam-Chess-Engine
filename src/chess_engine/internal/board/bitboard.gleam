import gleam/int
import gleam/list

pub type BitBoard =
  Int

pub const full_bitboard = 0xff_ff_ff_ff_ff_ff_ff_ff

pub fn bitboard_of(location: Int) -> BitBoard {
  int.bitwise_shift_left(1, location)
  |> int.bitwise_and(full_bitboard)
}

pub fn enforce(bitboard: BitBoard) -> BitBoard {
  int.bitwise_and(bitboard, full_bitboard)
}

pub fn not(bitboard: BitBoard) -> BitBoard {
  int.bitwise_exclusive_or(bitboard, full_bitboard)
}

pub fn add_to_bitboard(bitboard: BitBoard, location: Int) -> BitBoard {
  int.bitwise_or(bitboard, bitboard_of(location))
}

pub fn remove_from_bitboard(bitboard: BitBoard, location: Int) -> BitBoard {
  int.bitwise_and(bitboard, not(bitboard_of(location)))
}

pub fn value_on_bitboard(bitboard: BitBoard, at location: Int) -> Int {
  bitboard_of(location)
  |> int.bitwise_and(bitboard)
  |> int.bitwise_shift_right(location)
}

pub fn is_on_bitboard(bitboard: BitBoard, at location: Int) -> Bool {
  value_on_bitboard(bitboard, at: location)
  |> fn(x) { x == 1 }
}

pub fn generate_bitboard(from: List(Int)) {
  list.fold(from, 0, add_to_bitboard)
}

pub fn isolate_lsb(bitboard: BitBoard) -> BitBoard {
  bitboard
  |> int.bitwise_not()
  |> int.add(1)
  |> int.bitwise_and(bitboard)
}
