import bravo.{type BravoError}
import bravo/uset.{type USet}
import chess_engine/internal/board/board.{type Board}
import chess_engine/internal/board/fen
import chess_engine/internal/board/move
import chess_engine/internal/book_database.{type MoveEntry}
import chess_engine/internal/evaluation/evaluate.{type BoardValue, BookMove}
import chess_engine/internal/evaluation/zobrist.{type HashGenerator}
import gleam/list
import gleam/result

// import chess_engine/internal/board/move.{type Move}
// import gleam/option.{type Option}

pub type EntryScore {
  Exact(score: BoardValue)
  LowerBound(score: BoardValue)
  UpperBound(score: BoardValue)
}

pub type TranspositionEntry {
  TranspositionEntry(
    encoding: Int,
    depth: Int,
    score: EntryScore,
    // best_move: Option(Move),
  )
}

pub type TranspositionTable {
  TranspositionTable(
    generator: HashGenerator,
    table: USet(Int, TranspositionEntry),
  )
}

pub fn create_table(generator_seed seed: Int) {
  use table <- result.try(uset.new("Transposition", bravo.Public))

  TranspositionTable(generator: zobrist.create_hash(seed), table:)
  |> Ok()
}

pub fn delete_table(table: TranspositionTable) {
  uset.delete(table.table)
}

pub fn try_lookup(
  table: TranspositionTable,
  hash: Int,
) -> Result(TranspositionEntry, Nil) {
  uset.lookup(table.table, hash)
  |> result.replace_error(Nil)
}

pub fn save(
  table: TranspositionTable,
  entry: TranspositionEntry,
) -> Result(Nil, BravoError) {
  case try_lookup(table, entry.encoding) {
    Ok(existing) if existing.depth > entry.depth -> Ok(Nil)
    _ -> {
      uset.insert(table.table, entry.encoding, entry)
    }
  }
}

pub fn fill_table_with_book(table: TranspositionTable) {
  use entries <- result.try(book_database.read_entries())

  use starting_board <- result.try(
    fen.create_board(fen.default_fen) |> result.replace_error("Creation Error"),
  )

  let hash = zobrist.encode_board(table.generator, starting_board)

  list.each(entries, add_move_entry_to_table(table, _, starting_board, hash))
  Ok(Nil)
}

fn add_move_entry_to_table(
  table: TranspositionTable,
  move_entry: MoveEntry,
  board: Board,
  hash: Int,
) {
  let new_board = move.move(board, move_entry.move)
  use new_hash <- result.try(zobrist.encode_move(
    table.generator,
    hash,
    board,
    new_board,
    move_entry.move,
  ))

  let _ =
    TranspositionEntry(
      encoding: new_hash,
      depth: 100,
      score: Exact(BookMove(move_entry.count)),
    )
    |> save(table, _)

  list.each(move_entry.children, add_move_entry_to_table(
    table,
    _,
    new_board,
    new_hash,
  ))

  Ok(Nil)
}
