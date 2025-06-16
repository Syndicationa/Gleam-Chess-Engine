import chess_engine/internal/board/board.{type Board, type Color, Black, White}
import chess_engine/internal/board/fen.{type CreationError}
import chess_engine/internal/board/move.{type Move}
import chess_engine/internal/board/print
import chess_engine/internal/evaluation/evaluate
import chess_engine/internal/evaluation/search.{type SearchError}
import chess_engine/internal/generation/move_dictionary.{type MoveDictionary}
import chess_engine/internal/generation/move_generation

// import chess_engine/internal/perft
// import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree

// import gleam/time/duration
// import gleam/time/timestamp
import input

pub type GamePlayError {
  InvalidFEN(CreationError)
  InvalidInput(String)
  MajorSearchError(SearchError)
}

pub type GameState {
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
      use move <- result.try(
        move.from_string(str, board_data)
        |> result.map_error(move.error_to_string),
      )
      list.find(move_list, fn(x) { x == move })
      |> result.replace_error("Move is not allowed!")
      |> result.map(MoveRequest)
    }
  }
}

fn print_information_request(
  board_data: Board,
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
      evaluate.board_value(board_data)
      |> int.to_string
      |> string.append(to: "Board evaluated at: ", suffix: _)
      |> io.println()
    BestMove -> io.println("This feature is not ready!")
    PrintBoard ->
      print.to_string(board_data, board_data.active_color) |> io.println()
  }
}

fn human_turn(
  dictionary: MoveDictionary,
  board_data: Board,
) -> Result(GameState, GamePlayError) {
  let moves = move_generation.get_all_moves(dictionary, board_data)
  let in_check =
    move_generation.in_check(dictionary, board_data, board_data.active_color)

  case moves {
    [] if in_check ->
      Ok(Over(winner: board.opposite_color(board_data.active_color)))
    [] -> Ok(Stalemate)
    _ -> {
      let player_move =
        handle_input(
          "Move " <> int.to_string(board_data.move_count) <> ": ",
          read_game_input(board_data, moves, _),
        )

      case player_move {
        InformationRequest(value) -> {
          print_information_request(board_data, moves, value)
          human_turn(dictionary, board_data)
        }
        MoveRequest(move) ->
          move.move(board_data, move)
          |> computer_turn(dictionary, _)
        QuitRequest -> {
          print.to_string(board_data, board_data.active_color) |> io.println()
          io.println("Will add a FEN output soon!")
          Ok(Quit)
        }
      }
    }
  }
}

fn print_then_human(dictionary: MoveDictionary, board_data: Board) {
  print.to_string(board_data, board_data.active_color) |> io.println()
  human_turn(dictionary, board_data)
}

fn computer_turn(
  dictionary: MoveDictionary,
  board_data: Board,
) -> Result(GameState, GamePlayError) {
  let moves = move_generation.get_all_moves(dictionary, board_data)
  let in_check =
    move_generation.in_check(dictionary, board_data, board_data.active_color)

  case moves {
    [] if in_check ->
      Ok(Over(winner: board.opposite_color(board_data.active_color)))
    [] -> Ok(Stalemate)
    _ -> {
      use chosen_move <- result.try(
        search.search_at_depth(dictionary, board_data, 3, 5)
        |> result.map_error(MajorSearchError),
      )
      move.move(board_data, chosen_move)
      |> print_then_human(dictionary, _)
    }
  }
}

pub fn game(from: String) -> Result(GameState, GamePlayError) {
  use board <- result.try(
    fen.create_board(from) |> result.map_error(InvalidFEN),
  )

  let dictionary = move_dictionary.generate_move_dict()

  let team =
    handle_input("Which side will you play(W/B)?: ", fn(str) {
      case string.lowercase(str) {
        "w" | "white" -> Ok(White)
        "b" | "black" -> Ok(Black)
        _ -> Error("Not a side")
      }
    })

  case board.active_color == team {
    True -> print_then_human(dictionary, board)
    False -> computer_turn(dictionary, board)
  }
}
