import bravo.{type BravoError}
import chess_engine/internal/board/algebraic_notation
import chess_engine/internal/board/board.{type Board, type Color, Black, White}
import chess_engine/internal/board/fen.{type CreationError}
import chess_engine/internal/board/move.{type Move}
import chess_engine/internal/board/print
import chess_engine/internal/evaluation/evaluate
import chess_engine/internal/evaluation/search.{
  type GameState, type SearchError, GameState,
}
import chess_engine/internal/evaluation/transposition
import chess_engine/internal/evaluation/zobrist
import chess_engine/internal/generation/move_dictionary
import chess_engine/internal/generation/move_generation

// import chess_engine/internal/perft
// import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree

import input

pub type GamePlayError {
  InvalidFEN(CreationError)
  TranspositionTableFailure(BravoError)
  InvalidInput(String)
  MajorSearchError(SearchError)
}

pub type GameResult {
  Stalemate
  Over(winner: Color)
  Quit
}

type InformationRequest {
  MoveList
  Help
  Evaluation
  BestMove
  PrintBoard
}

type Input {
  MoveRequest(Move)
  InformationRequest(InformationRequest)
  QuitRequest
}

///Handles inputs by looping until it reaches a state where the mapper will return an Ok() result, where it will pass the value on
fn handle_input(request: String, mapper: fn(String) -> Result(a, _)) -> a {
  io.println("")
  let input_result = input.input(request)

  case input_result {
    Error(_) -> handle_input(request, mapper)
    Ok(string) ->
      case mapper(string) {
        Ok(final) -> final
        Error(x) -> {
          io.println(x)
          handle_input(request, mapper)
        }
      }
  }
}

fn read_game_input(
  board_data: Board,
  move_list: List(Move),
  str: String,
) -> Result(Input, String) {
  case string.lowercase(str) {
    "list" | "moves" -> InformationRequest(MoveList) |> Ok
    "help" -> InformationRequest(Help) |> Ok
    "eval" -> InformationRequest(Evaluation) |> Ok
    "best" -> InformationRequest(BestMove) |> Ok
    "print" -> InformationRequest(PrintBoard) |> Ok
    "q" | "quit" -> QuitRequest |> Ok
    _ -> {
      let standard_move =
        move.from_string(str, board_data)
        |> result.map_error(move.error_to_string)

      let algebraic_move =
        algebraic_notation.create_move(board_data, str, move_list)
        |> result.map_error(move.error_to_string)

      use move <- result.try(result.or(standard_move, algebraic_move))

      list.find(move_list, fn(x) { x == move })
      |> result.replace_error("Move is not allowed!")
      |> result.map(MoveRequest)
    }
  }
}

fn print_information_request(
  game_state: GameState,
  move_list: List(Move),
  request: InformationRequest,
) {
  case request {
    MoveList ->
      list.map(move_list, move.to_string)
      |> string_tree.from_strings()
      |> string_tree.to_string()
      |> io.println()
    Help ->
      io.println(
        "Commands:
    list, moves - These will list your possible moves
    help - Provides this list
    eval - Gives you the evaluation of this board
    best - Will provide the best move as calculated by the bot
    print - Reprints the board
    q, quit - Quit the Game
    
    All other inputs will be considered moves",
      )
    Evaluation ->
      evaluate.board_value(game_state.board)
      |> int.to_string
      |> string.append(to: "Board evaluated at: ", suffix: _)
      |> io.println()
    BestMove ->
      search.search_at_depth(game_state, 3, 5)
      |> result.map(move.to_string)
      |> result.unwrap("Error was encountered")
      |> io.println()
    PrintBoard ->
      print.to_string(game_state.board, game_state.board.active_color)
      |> io.println()
  }
}

fn human_turn(game_state: GameState) -> Result(GameResult, GamePlayError) {
  let moves =
    move_generation.get_all_moves(game_state.dictionary, game_state.board)
  let in_check =
    move_generation.in_check(game_state.dictionary, game_state.board)

  case moves {
    [] if in_check ->
      Ok(Over(winner: board.opposite_color(game_state.board.active_color)))
    [] -> Ok(Stalemate)
    _ -> {
      let player_move =
        handle_input(
          "Move " <> int.to_string(game_state.board.move_count) <> ": ",
          read_game_input(game_state.board, moves, _),
        )

      case player_move {
        InformationRequest(value) -> {
          print_information_request(game_state, moves, value)
          human_turn(game_state)
        }
        MoveRequest(move) -> {
          let new_board = move.move(game_state.board, move)
          let new_hash =
            zobrist.encode_move(
              game_state.transposition.generator,
              game_state.hash,
              game_state.board,
              new_board,
              move,
            )
            //This unwrap should never happen, but if it does, using a random new hash would move the state randomly is the area
            |> result.unwrap(zobrist.random(game_state.hash))

          GameState(..game_state, board: new_board, hash: new_hash)
          |> computer_turn()
        }
        QuitRequest -> {
          print.to_string(game_state.board, game_state.board.active_color)
          |> io.println()
          io.println("Will add a FEN output soon!")
          Ok(Quit)
        }
      }
    }
  }
}

fn print_then_human(game_state: GameState) {
  print.to_string(game_state.board, game_state.board.active_color)
  |> io.println()
  human_turn(game_state)
}

fn computer_turn(game_state: GameState) -> Result(GameResult, GamePlayError) {
  let moves =
    move_generation.get_all_moves(game_state.dictionary, game_state.board)
  let in_check =
    move_generation.in_check(game_state.dictionary, game_state.board)

  case moves {
    [] if in_check ->
      Ok(Over(winner: board.opposite_color(game_state.board.active_color)))
    [] -> Ok(Stalemate)
    _ -> {
      use chosen_move <- result.try(
        search.search_for_time(game_state, 2000, 135)
        |> result.map_error(MajorSearchError),
      )

      echo chosen_move
      io.println(move.to_string(chosen_move))

      let new_board = move.move(game_state.board, chosen_move)
      let new_hash =
        zobrist.encode_move(
          game_state.transposition.generator,
          game_state.hash,
          game_state.board,
          new_board,
          chosen_move,
        )
        //This unwrap should never happen, but if it does, using a random new hash would move the state randomly is the area
        |> result.unwrap(zobrist.random(game_state.hash))
      GameState(..game_state, board: new_board, hash: new_hash)
      |> print_then_human()
    }
  }
}

fn after_game(transposition_table, callback) {
  let result = callback()

  transposition.delete_table(transposition_table)
  |> result.unwrap(Nil)

  result
}

pub fn game(from: String) -> Result(GameResult, GamePlayError) {
  use board <- result.try(
    fen.create_board(from) |> result.map_error(InvalidFEN),
  )

  use transposition <- result.try(
    transposition.create_table(10)
    |> result.map_error(TranspositionTableFailure),
  )

  use <- after_game(transposition)

  let did_build_book = transposition.fill_table_with_book(transposition)

  case did_build_book {
    Ok(_) -> io.println("Built Book!\n")
    Error(s) -> io.println("Failed to build book due to " <> s)
  }

  let dictionary = move_dictionary.generate_move_dict()
  let hash = zobrist.encode_board(transposition.generator, board)

  let game_state = GameState(transposition:, dictionary:, board:, hash:)

  let team =
    handle_input("Which side will you play(W/B)?: ", fn(str) {
      case string.lowercase(str) {
        "w" | "white" -> Ok(White)
        "b" | "black" -> Ok(Black)
        _ -> Error("Not a side")
      }
    })

  case board.active_color == team {
    True -> print_then_human(game_state)
    False -> computer_turn(game_state)
  }
}
