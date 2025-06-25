import chess_engine/internal/board/board.{type Board}
import chess_engine/internal/board/move.{type Move}
import chess_engine/internal/evaluation/evaluate.{
  type BoardValue, Checkmate, Stalemate, Unrated,
}
import chess_engine/internal/evaluation/transposition.{
  type TranspositionTable, Exact, LowerBound, TranspositionEntry, UpperBound,
}
import chess_engine/internal/evaluation/zobrist
import chess_engine/internal/generation/move_dictionary.{type MoveDictionary}
import chess_engine/internal/generation/move_generation
import chess_engine/internal/helper
import gleam/bool
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{None, Some}
import gleam/order.{Gt, Lt}
import gleam/result

pub type GameState {
  GameState(
    transposition: TranspositionTable,
    dictionary: MoveDictionary,
    board: Board,
    hash: Int,
  )
}

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
  game: GameState,
  best_score_for_us: BoardValue,
  best_score_for_them: BoardValue,
  depth: Int,
  true_depth: Int,
) -> BoardValue {
  use <- bool.guard(
    depth == 0 || true_depth == 0,
    evaluate.evaluate(game.dictionary, game.board),
  )

  let previous_score = transposition.try_lookup(game.transposition, game.hash)

  let good_entry = case previous_score {
    Ok(entry) if entry.depth >= depth -> {
      case entry.score {
        Exact(score) -> Some(score)
        LowerBound(score) ->
          { evaluate.compare(score, best_score_for_them) == Gt }
          |> helper.ternary(Some(score), None)
        UpperBound(score) ->
          { evaluate.compare(score, best_score_for_us) == Lt }
          |> helper.ternary(Some(score), None)
      }
    }
    _ -> None
  }

  use <- option.lazy_unwrap(good_entry)

  let moves = move_generation.get_all_moves(game.dictionary, game.board)
  let in_check = move_generation.in_check(game.dictionary, game.board)

  case moves {
    [] if in_check -> Checkmate(in: 0)
    [] -> Stalemate
    moves -> {
      let acc =
        sort_prescore_moves(moves)
        |> list.fold_until(nmacc(best_score_for_us), fn(acc, move_data) {
          let new_board = move.move(game.board, move_data)
          let new_hash =
            zobrist.encode_move(
              game.transposition.generator,
              game.hash,
              game.board,
              new_board,
              move_data,
            )
            //This unwrap should never happen, but if it does, using a random new hash would move the state randomly is the area
            |> result.unwrap(zobrist.random(game.hash))

          let evaluation =
            negamax(
              GameState(..game, board: new_board, hash: new_hash),
              evaluate.add_ply(best_score_for_them),
              evaluate.add_ply(best_score_for_us),
              depth - 1,
              true_depth - 1,
            )
            |> evaluate.add_ply()

          let new_acc = update_accumulator(acc, evaluation)

          let better_than_theyd_allow =
            evaluate.compare(evaluation, best_score_for_them) != Lt
          let better_than_we_can_get =
            evaluate.compare(evaluation, best_score_for_us) != Gt

          let score = case Nil {
            _ if better_than_theyd_allow -> LowerBound(evaluation)
            _ if better_than_we_can_get -> UpperBound(evaluation)
            _ -> Exact(evaluation)
          }

          transposition.save(
            game.transposition,
            TranspositionEntry(encoding: new_hash, depth:, score:),
          )
          |> result.unwrap(Nil)

          case better_than_theyd_allow {
            True -> Stop(new_acc)
            False -> Continue(new_acc)
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
  game: GameState,
  depth: Int,
  true_depth: Int,
) -> Result(Move, SearchError) {
  let move_list =
    move_generation.get_all_moves(game.dictionary, game.board)
    |> sort_prescore_moves()

  case move_list {
    [] -> Error(NoLegalMoves)
    [single_move] -> Ok(single_move)
    [first, ..] -> {
      let accumulator =
        list.fold(move_list, search_acc(first), fn(accumulator, move_data) {
          let new_board = move.move(game.board, move_data)
          let new_hash =
            zobrist.encode_move(
              game.transposition.generator,
              game.hash,
              game.board,
              new_board,
              move_data,
            )
            //This unwrap should never happen, but if it does, using a random new hash would move the state randomly is the area
            |> result.unwrap(zobrist.random(game.hash))

          let evaluation =
            negamax(
              GameState(..game, board: new_board, hash: new_hash),
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
