import gleam/bool
import gleam/int
import gleam/list

pub type BitBoard =
  Int

fn fast_bit_length(number: BitBoard, count: Int) -> Int {
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
pub fn bit_length(number: BitBoard) -> Int {
  fast_bit_length(number, 0)
}

pub fn get_index(number: BitBoard) -> Int {
  bit_length(number) - 1
}

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

pub fn nimply(first a: BitBoard, second b: BitBoard) -> BitBoard {
  not(b)
  |> int.bitwise_and(a)
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

pub fn fold(
  bitboard bb: BitBoard,
  initial acc: generic,
  folder f: fn(generic, Int) -> generic,
) -> generic {
  use <- bool.guard(bb == 0, acc)

  let lsb = isolate_lsb(bb)
  let idx = get_index(lsb)

  fold(
    //Remove the LSB
    int.bitwise_exclusive_or(bb, lsb),
    f(acc, idx),
    f,
  )
}
