import chess_engine/internal/bitboard

pub fn is_on_bitboard_test() {
  assert bitboard.is_on_bitboard(0b111, 0)
  assert bitboard.is_on_bitboard(0b111, 1)
  assert bitboard.is_on_bitboard(0b111, 2)
  assert !bitboard.is_on_bitboard(0b111, 3)
}
