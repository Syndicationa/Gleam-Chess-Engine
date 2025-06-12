import chess_engine/internal/board.{type Board}
import chess_engine/internal/move
import chess_engine/internal/move_dictionary.{type MoveDictionary}
import chess_engine/internal/move_generation
import gleam/bool
import gleam/int
import gleam/list

pub fn perft(board_data: Board, depth: Int) -> Int {
  let table = move_dictionary.generate_move_dict()

  perft_loop(table, board_data, depth)
}

fn perft_loop(table: MoveDictionary, board_data: Board, depth: Int) -> Int {
  use <- bool.guard(depth == 0, 1)

  move_generation.get_all_moves(table, board_data)
  |> list.fold(0, fn(current_count, new_move) {
    move.move(board_data, new_move)
    |> perft_loop(table, _, depth - 1)
    |> fn(x) {
      use <- bool.guard(depth != 100, x)

      echo #(move.to_string(new_move), x)

      x
    }
    |> int.add(current_count)
  })
}
