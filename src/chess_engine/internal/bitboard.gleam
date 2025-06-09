import gleam/int

pub type BitBoard =
  Int

pub const full_bitboard = 0xff_ff_ff_ff_ff_ff_ff_ff

pub fn bitboard_of(location: Int) -> BitBoard {
  case int.clamp(location, min: 0, max: 63) == location {
    False -> 0
    True -> int.bitwise_shift_left(1, location)
  }
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
