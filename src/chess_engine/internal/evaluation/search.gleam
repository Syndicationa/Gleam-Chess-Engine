import chess_engine/internal/board/board.{type Board}
import chess_engine/internal/board/move.{type Move}
import chess_engine/internal/evaluation/evaluate.{
  type BoardValue, Checkmate, Stalemate, Unrated,
}
import chess_engine/internal/generation/move_dictionary.{type MoveDictionary}
import chess_engine/internal/generation/move_generation
import gleam/bool
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/order.{Lt}

fn sort_prescore_moves(moves: List(Move)) {
  list.sort(moves, fn(move_a, move_b) {
    let move_a_score = evaluate.prescore_move(move_a)
    let move_b_score = evaluate.prescore_move(move_b)

    int.compare(move_b_score, move_a_score)
  })
}

type NegamaxAccumulator {
  NMACC(best_score_for_us: BoardValue, best_score_in_loop: BoardValue)
}

fn nmacc(best_score_for_us: BoardValue) {
  NMACC(best_score_for_us:, best_score_in_loop: Unrated)
}

fn update_accumulator(
  acc: NegamaxAccumulator,
  value: BoardValue,
) -> NegamaxAccumulator {
  NMACC(
    best_score_for_us: evaluate.max(acc.best_score_for_us, value),
    best_score_in_loop: evaluate.max(acc.best_score_in_loop, value),
  )
}

fn negamax(
  table: MoveDictionary,
  board_data: Board,
  best_score_for_us: BoardValue,
  best_score_for_them: BoardValue,
  depth: Int,
  true_depth: Int,
) -> BoardValue {
  use <- bool.guard(
    depth == 0 || true_depth == 0,
    evaluate.evaluate(table, board_data),
  )
  let moves = move_generation.get_all_moves(table, board_data)
  let in_check =
    move_generation.in_check(table, board_data, board_data.active_color)

  case moves {
    [] if in_check -> Checkmate(in: 0)
    [] -> Stalemate
    moves -> {
      let acc =
        sort_prescore_moves(moves)
        |> list.fold_until(nmacc(best_score_for_us), fn(acc, move_data) {
          let new_board = move.move(board_data, move_data)

          let evaluation =
            negamax(
              table,
              new_board,
              evaluate.add_ply(best_score_for_them),
              evaluate.add_ply(best_score_for_us),
              bool.guard(in_check, depth, fn() { depth - 1 }),
              true_depth - 1,
            )
            |> evaluate.add_ply()

          let new_acc = update_accumulator(acc, evaluation)

          case evaluate.compare(evaluation, best_score_for_them) {
            Lt -> Continue(new_acc)
            _ -> Stop(new_acc)
          }
        })

      acc.best_score_in_loop
    }
  }
}

type SearchAccumulator {
  SearchAcc(best_score_for_us: BoardValue, best_move: Move)
}

fn search_acc(first_move: Move) {
  SearchAcc(best_score_for_us: Unrated, best_move: first_move)
}

fn update_search_accumulator(
  acc: SearchAccumulator,
  value: BoardValue,
  move: Move,
) -> SearchAccumulator {
  case evaluate.compare(acc.best_score_for_us, value) {
    Lt -> SearchAcc(value, move)
    _ -> acc
  }
}

pub type SearchError {
  NoLegalMoves
}

pub fn search_at_depth(
  table: MoveDictionary,
  board_data: Board,
  depth: Int,
  true_depth: Int,
) -> Result(Move, SearchError) {
  let move_list =
    move_generation.get_all_moves(table, board_data)
    |> sort_prescore_moves()

  case move_list {
    [] -> Error(NoLegalMoves)
    [single_move] -> Ok(single_move)
    [first, ..] -> {
      let accumulator =
        list.fold(move_list, search_acc(first), fn(accumulator, move_data) {
          let new_board = move.move(board_data, move_data)

          let evaluation =
            negamax(
              table,
              new_board,
              Unrated,
              evaluate.add_ply(accumulator.best_score_for_us),
              depth - 1,
              true_depth - 1,
            )
            |> evaluate.add_ply()

          update_search_accumulator(accumulator, evaluation, move_data)
        })

      Ok(accumulator.best_move)
    }
  }
}
