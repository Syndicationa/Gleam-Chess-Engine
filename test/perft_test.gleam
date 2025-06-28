import chess_engine/internal/board/board.{King, Knight, Pawn, Queen}
import chess_engine/internal/board/fen
import chess_engine/internal/board/move.{type Move, Capture, Move, Normal}
import chess_engine/internal/perft
import gleam/option.{None}

const kiwipete = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"

const position_3 = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"

const position_4 = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"

const position_5 = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"

const position_6 = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"

pub fn perft_from_start_test() {
  let assert Ok(board) = fen.create_board(fen.default_fen)
  assert perft.perft(board, 0) == 1 as "Depth 0"
  assert perft.perft(board, 1) == 20 as "Depth 1"
  assert perft.perft(board, 2) == 400 as "Depth 2"
  assert perft.perft(board, 3) == 8902 as "Depth 3"
  assert perft.perft(board, 4) == 197_281 as "Depth 4"
}

pub fn perft_from_kiwipete_test() {
  let assert Ok(board) = fen.create_board(kiwipete)
  assert perft.perft(board, 0) == 1 as "Depth 0"
  assert perft.perft(board, 1) == 48 as "Depth 1"
  assert perft.perft(board, 2) == 2039 as "Depth 2"
  assert perft.perft(board, 3) == 97_862 as "Depth 3"
}

pub fn perft_from_position_3_test() {
  let assert Ok(board) = fen.create_board(position_3)
  assert perft.perft(board, 0) == 1 as "Depth 0"
  assert perft.perft(board, 1) == 14 as "Depth 1"
  assert perft.perft(board, 2) == 191 as "Depth 2"
  assert perft.perft(board, 3) == 2812 as "Depth 3"
  assert perft.perft(board, 4) == 43_238 as "Depth 4"
}

pub fn perft_from_position_4_test() {
  let assert Ok(board) = fen.create_board(position_4)
  assert perft.perft(board, 0) == 1 as "Depth 0"
  assert perft.perft(board, 1) == 6 as "Depth 1"
  assert perft.perft(board, 2) == 264 as "Depth 2"
  assert perft.perft(board, 3) == 9467 as "Depth 3"
  assert perft.perft(board, 4) == 422_333 as "Depth 4"
}

pub fn perft_from_position_5_test() {
  let assert Ok(board) = fen.create_board(position_5)
  assert perft.perft(board, 0) == 1 as "Depth 0"
  assert perft.perft(board, 1) == 44 as "Depth 1"
  assert perft.perft(board, 2) == 1486 as "Depth 2"
  assert perft.perft(board, 3) == 62_379 as "Depth 3"
}

pub fn perft_from_position_6_test() {
  let assert Ok(board) = fen.create_board(position_6)
  assert perft.perft(board, 0) == 1 as "Depth 0"
  assert perft.perft(board, 1) == 46 as "Depth 1"
  assert perft.perft(board, 2) == 2079 as "Depth 2"
  assert perft.perft(board, 3) == 89_890 as "Depth 3"
}

const reti: Move = Move(
  piece: Knight,
  source: 0o0_6,
  target: 0o2_5,
  data: Normal,
)

const a2a3 = Move(piece: Pawn, source: 0o1_0, target: 0o2_0, data: Normal)

const d5d6 = Move(piece: Pawn, source: 0o4_3, target: 0o5_3, data: Normal)

const b4b3 = Move(piece: Pawn, source: 0o3_1, target: 0o2_1, data: Normal)

const e2e4 = Move(piece: Pawn, source: 0o1_4, target: 0o3_4, data: Normal)

const c7c6 = Move(piece: Pawn, source: 0o6_2, target: 0o5_2, data: Normal)

const e5d7_kiwi = Move(
  piece: Knight,
  source: 0o4_4,
  target: 0o6_3,
  data: Capture(Pawn),
)

const c3b1_kiwi = Move(
  piece: Knight,
  source: 0o2_2,
  target: 0o0_1,
  data: Normal,
)

const e1f1_kiwi = Move(piece: King, source: 0o0_4, target: 0o0_5, data: Normal)

const e1d2_pos_5 = Move(piece: King, source: 0o0_4, target: 0o1_3, data: Normal)

const d8d7_pos_5 = Move(
  piece: Queen,
  source: 0o7_3,
  target: 0o6_3,
  data: Capture(Pawn),
)

const e2g1_pos_5 = Move(
  piece: Knight,
  source: 0o1_4,
  target: 0o0_6,
  data: Normal,
)

const d8a5_pos_5 = Move(
  piece: Queen,
  source: 0o7_3,
  target: 0o4_0,
  data: Normal,
)

pub fn kiwipete_e1f1_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let e1f1 = board |> move.move(e1f1_kiwi)

  assert perft.perft(e1f1, 2) == 1855 as "Depth 2"
}

pub fn kiwipete_c3b1_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let c3b1 = board |> move.move(c3b1_kiwi)

  assert perft.perft(c3b1, 2) == 2038 as "Depth 2"
}

pub fn kiwipete_c3b1_b4b3_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let b4b3 = board |> move.move(c3b1_kiwi) |> move.move(b4b3)

  assert perft.perft(b4b3, 1) == 50 as "Depth 1"
}

pub fn kiwipete_a2a3_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let a2a3 = board |> move.move(a2a3)
  assert perft.perft(a2a3, 1) == 44 as "Depth 1"
}

pub fn kiwipete_d5d6_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let d5d6 = board |> move.move(d5d6)
  assert perft.perft(d5d6, 2) == 1991 as "Depth 2"
}

pub fn kiwipete_b4b3_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let b4b3 = board |> move.move(d5d6) |> move.move(b4b3)
  assert perft.perft(b4b3, 1) == 50 as "Depth 1"
}

pub fn kiwipete_e5d7_test() {
  let assert Ok(board) = fen.create_board(kiwipete)

  let e5d7 = board |> move.move(e5d7_kiwi)
  assert perft.perft(e5d7, 1) == 45 as "Depth 1"
}

pub fn pos3_e2e4_test() {
  let assert Ok(board) = fen.create_board(position_3)

  let e2e4 = board |> move.move(e2e4)
  assert perft.perft(e2e4, 1) == 16 as "Depth 1"
  assert perft.perft(e2e4, 2) == 177 as "Depth 2"
}

pub fn pos3_c7c6_test() {
  let assert Ok(board) = fen.create_board(position_3)

  let c7c6 = board |> move.move(e2e4) |> move.move(c7c6)

  assert perft.perft(c7c6, 1) == 12 as "Depth 1"
}

pub fn pos5_a2a3_test() {
  let assert Ok(board) = fen.create_board(position_5)

  let a2a3 = board |> move.move(a2a3)

  assert perft.perft(a2a3, 2) == 1373 as "Depth 2"
}

pub fn pos5_e1d2_test() {
  let assert Ok(board) = fen.create_board(position_5)

  let e1d2 = board |> move.move(e1d2_pos_5)

  assert perft.perft(e1d2, 2) == 978 as "Depth 2"
}

pub fn pos5_d8d7_test() {
  let assert Ok(board) = fen.create_board(position_5)

  let d8d7 = board |> move.move(e1d2_pos_5) |> move.move(d8d7_pos_5)

  assert perft.perft(d8d7, 1) == 6 as "Depth 1"
}

pub fn pos5_e2g1_test() {
  let assert Ok(board) = fen.create_board(position_5)

  let e2g1 = board |> move.move(e2g1_pos_5)

  assert perft.perft(e2g1, 2) == 1431 as "Depth 2"
}

pub fn pos5_d8a5_test() {
  let assert Ok(board) = fen.create_board(position_5)

  let d8a5 = board |> move.move(e2g1_pos_5) |> move.move(d8a5_pos_5)

  assert perft.perft(d8a5, 1) == 9 as "Depth 1"
}

pub fn from_reti_test() {
  let assert Ok(board) = fen.create_board(fen.default_fen)
  //   echo reti
  let reti =
    board
    |> move.move(reti)

  assert reti.en_passant_square == None
  assert perft.perft(reti, 1) == 20 as "Depth 1"
  assert perft.perft(reti, 2) == 440 as "Depth 2"
}

pub fn rook_slide_test() {
  let assert Ok(board) = fen.create_board("k1K5/8/8/8/8/8/8/7R w - - 0 1")
  assert perft.perft(board, 1) == 17 as "Example"
}
// const useful = 1
