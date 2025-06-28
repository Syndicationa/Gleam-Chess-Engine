import chess_engine/internal/board/board.{type Board}
import chess_engine/internal/board/move.{type Move}
import chess_engine/internal/evaluation/evaluate.{
  type BoardValue, BookMove, Checkmate, Stalemate, Unrated, Value,
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
import gleam/list.{Continue, Stop}
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/pair
import gleam/result
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}

pub type GameState {
  GameState(
    transposition: TranspositionTable,
    dictionary: MoveDictionary,
    board: Board,
    hash: Int,
  )
}

type TimeState {
  DepthSearch
  TimeState(start: Timestamp, search_time: Duration)
}

fn has_time_elapsed(time: TimeState) {
  case time {
    DepthSearch -> False
    TimeState(start, search_time) -> {
      let now = timestamp.system_time()

      timestamp.difference(start, now)
      |> duration.compare(search_time)
      |> fn(x) { x != Lt }
    }
  }
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

const unrated_nmacc = NMACC(Unrated, Unrated)

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
  time: TimeState,
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
          { evaluate.compare(score, best_score_for_them) != Lt }
          |> helper.ternary(Some(score), None)
        UpperBound(score) ->
          { evaluate.compare(score, best_score_for_us) != Gt }
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
              time,
            )
            |> evaluate.add_ply()

          use <- bool.guard(evaluation == Unrated, Stop(unrated_nmacc))
          use <- bool.guard(has_time_elapsed(time), Stop(unrated_nmacc))
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
  RandomOutOfBounds
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
              DepthSearch,
            )
            |> evaluate.add_ply()

          update_search_accumulator(accumulator, evaluation, move_data)
        })

      Ok(accumulator.best_move)
    }
  }
}

type IteratorAccumulator {
  IteratorAccumulator(best_score: BoardValue, stop: Bool)
}

fn iter_acc() {
  IteratorAccumulator(best_score: Unrated, stop: False)
}

fn update_acc(acc: IteratorAccumulator, score: BoardValue) {
  let best_score = evaluate.max(acc.best_score, score)
  let stop = score == Unrated

  IteratorAccumulator(best_score:, stop:)
}

type MoveScore {
  MoveScore(move: Move, score: BoardValue)
}

fn create_move_score(move: Move) {
  MoveScore(move:, score: Value(evaluate.prescore_move(move)))
}

fn update_move_score(move_score: MoveScore, score: BoardValue) -> MoveScore {
  use <- bool.guard(score == Unrated, move_score)

  MoveScore(..move_score, score:)
}

fn sort_move_scores(moves: List(MoveScore)) {
  list.sort(moves, fn(a, b) { evaluate.compare(b.score, a.score) })
}

fn iterative_deepening(
  game: GameState,
  move_list: List(MoveScore),
  time: TimeState,
  depth: Int,
) {
  use <- bool.guard(has_time_elapsed(time), move_list)
  use <- bool.guard(
    list.first(move_list)
      |> result.map(fn(ms_sc) {
        evaluate.compare(ms_sc.score, BookMove(1)) == Eq
      })
      |> result.unwrap(False),
    move_list,
  )
  echo "Starting Depth: " <> int.to_string(depth)

  list.map_fold(move_list, iter_acc(), fn(accumulator, move_score) {
    use <- bool.guard(accumulator.stop, #(accumulator, move_score))

    let new_board = move.move(game.board, move_score.move)
    let new_hash =
      zobrist.encode_move(
        game.transposition.generator,
        game.hash,
        game.board,
        new_board,
        move_score.move,
      )
      //This unwrap should never happen, but if it does, using a random new hash would move the state randomly is the area
      |> result.unwrap(zobrist.random(game.hash))

    let evaluation =
      negamax(
        GameState(..game, board: new_board, hash: new_hash),
        Unrated,
        evaluate.add_ply(accumulator.best_score),
        depth - 1,
        depth,
        time,
      )
      |> evaluate.add_ply()

    #(
      update_acc(accumulator, evaluation),
      update_move_score(move_score, evaluation),
    )
  })
  |> pair.second()
  |> sort_move_scores()
  |> iterative_deepening(game, _, time, depth + 1)
}

fn at_idx(list: List(MoveScore), at: Int, current_idx: Int) {
  use <- bool.guard(at == current_idx, list.first(list))

  case list {
    [] -> Error(Nil)
    [_, ..rest] -> at_idx(rest, at, current_idx + 1)
  }
}

pub fn search_for_time(
  game: GameState,
  time_ms: Int,
  seed: Int,
) -> Result(Move, SearchError) {
  let now = timestamp.system_time()
  let time = TimeState(now, duration.milliseconds(time_ms))

  let move_list =
    move_generation.get_all_moves(game.dictionary, game.board)
    |> list.map(create_move_score)
    |> sort_move_scores()

  case move_list {
    [] -> Error(NoLegalMoves)
    [single_move] -> Ok(single_move.move)
    [_, ..] -> {
      let outcome = iterative_deepening(game, move_list, time, 1)
      let score =
        list.first(outcome)
        |> result.map(fn(x) { x.score })
        |> result.unwrap(Unrated)

      let options =
        list.filter(outcome, fn(mv_sc) {
          evaluate.compare(mv_sc.score, score) == Eq
        })

      case score {
        BookMove(_) -> pick_random_book_move(seed, game, options)
        _ -> pick_random_move(seed, game, options)
      }
    }
  }
}

fn pick_random_book_move(
  seed: Int,
  game: GameState,
  options: List(MoveScore),
) -> Result(Move, SearchError) {
  let scan =
    list.scan(options, 0, fn(acc, ms_sc) {
      case ms_sc.score {
        BookMove(c) -> acc + c
        _ -> acc
      }
    })

  echo "Book Move"

  use size <- result.try(list.last(scan) |> result.replace_error(NoLegalMoves))

  let random =
    seed + game.hash
    |> zobrist.random()
    |> int.modulo(size)
    |> result.unwrap(0)

  list.zip(options, scan)
  |> list.drop_while(fn(combo) { random >= pair.second(combo) })
  |> list.first()
  |> result.map(pair.first)
  |> result.map(fn(x) { x.move })
  |> result.replace_error(RandomOutOfBounds)
}

fn pick_random_move(
  seed: Int,
  game: GameState,
  options: List(MoveScore),
) -> Result(Move, SearchError) {
  let option_count = list.length(options)
  let random =
    seed + game.hash
    |> zobrist.random()
    |> int.modulo(option_count)
    |> result.unwrap(0)

  at_idx(options, random, 0)
  |> result.map(fn(x) { x.move })
  |> result.replace_error(RandomOutOfBounds)
}
