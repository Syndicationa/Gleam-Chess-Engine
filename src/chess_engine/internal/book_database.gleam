import chess_engine/internal/board/algebraic_notation
import chess_engine/internal/board/board.{type Board}
import chess_engine/internal/board/fen.{type CreationError}
import chess_engine/internal/board/move.{type Move, Move}
import chess_engine/internal/board/print
import chess_engine/internal/generation/move_dictionary.{type MoveDictionary}
import chess_engine/internal/generation/move_generation
import gleam/bool
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode.{type Decoder}
import gleam/io
import gleam/json.{type Json}
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import simplifile

const file = "./database.pgn"

const target = "./database.moves"

pub type DecodedGame {
  DecodedGame(board_data: String, moves: List(Move))
}

pub type MoveEntry {
  MoveEntry(move: Move, count: Int, children: List(MoveEntry))
}

pub fn convert_game() {
  use text <- result.try(simplifile.read(file))

  let games = string.split(text, on: "\n\n[")

  let dictionary = move_dictionary.generate_move_dict()

  list.map(games, fn(game_str) {
    let assert [board_data, move_string_list, ..] =
      string.split(game_str, "\n\n")

    let moves =
      move_string_to_list(dictionary, move_string_list) |> result.unwrap([])

    DecodedGame(board_data: "[" <> board_data, moves:)
  })
  |> build_move_tree(10, 0)
  |> json.array(move_entry_to_json)
  |> json.to_string()
  |> simplifile.write(to: target, contents: _)
}

fn build_move_tree(
  game_list: List(DecodedGame),
  depth: Int,
  take_amount: Int,
) -> List(MoveEntry) {
  use <- bool.guard(depth <= 0, [])
  game_list
  |> list.group(fn(game: DecodedGame) {
    game.moves
    |> list.drop(take_amount)
    |> list.first()
  })
  |> dict.to_list()
  |> list.filter_map(fn(move_game) {
    let #(move, game) = move_game
    case move {
      Ok(move_data) -> Ok(#(move_data, game))
      _ -> Error(Nil)
    }
  })
  |> list.map(fn(move_game) {
    let #(move, game) = move_game

    let length = list.length(game)

    MoveEntry(
      move:,
      count: length,
      children: build_move_tree(game, depth - 1, take_amount + 1),
    )
  })
}

fn move_entry_to_json(entry: MoveEntry) -> Json {
  json.object([
    #("move", move.to_string(entry.move) |> json.string()),
    #("count", json.int(entry.count)),
    #("children", json.array(entry.children, move_entry_to_json)),
  ])
}

pub fn read_entries() {
  use string <- result.try(
    simplifile.read(target) |> result.replace_error("File Error"),
  )
  use board <- result.try(
    fen.create_board(fen.default_fen) |> result.replace_error("FEN Error"),
  )

  parse_move_entry(board, string)
  |> result.replace_error("Parsing Error")
}

fn parse_move_entry(board: Board, json_string: String) {
  use <- bool.guard(json_string == "", Ok([]))

  json.parse(json_string, decode.list(decode_move_entry(board)))
}

fn decode_move_entry(board) -> Decoder(MoveEntry) {
  use <- decode.recursive

  use move_str <- decode.field("move", decode.string)
  use count <- decode.field("count", decode.int)

  let move = move.from_string(move_str, board)

  case move {
    Ok(move) -> {
      let next_board = move.move(board, move)
      use children <- decode.field(
        "children",
        decode.list(decode_move_entry(next_board)),
      )
      decode.success(MoveEntry(move:, count:, children:))
    }
    Error(_) ->
      decode.failure(
        MoveEntry(
          move: Move(board.Pawn, 0, 0, move.Normal),
          count: 0,
          children: [],
        ),
        "Move issue",
      )
  }
}

fn move_string_to_list(
  dictionary: MoveDictionary,
  move_string: String,
) -> Result(List(Move), CreationError) {
  use board <- result.try(fen.create_board(fen.default_fen))

  string.replace(move_string, "\n", " ")
  |> string.split(on: " ")
  |> list.filter(fn(s) {
    string.contains(s, ".")
    |> bool.or(string.contains(s, "1-0"))
    |> bool.or(string.contains(s, "0-1"))
    |> bool.or(string.contains(s, "1/2-1/2"))
    |> bool.negate()
  })
  |> list.map_fold(board, fn(current_board, move_str) {
    let move_list = move_generation.get_all_moves(dictionary, current_board)
    let assert Ok(move_data) =
      algebraic_notation.create_move(current_board, move_str, move_list)
      |> result.map_error(fn(outcome) {
        echo outcome
        io.println(move_string)
        io.println(print.to_string(current_board, board.White))
        echo move_list
        outcome
      })

    #(move.move(current_board, move_data), move_data)
  })
  |> pair.second()
  |> Ok()
}
