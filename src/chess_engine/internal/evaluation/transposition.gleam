import bravo.{type BravoError}
import bravo/uset.{type USet}
import chess_engine/internal/board/move.{type Move}
import chess_engine/internal/evaluation/zobrist.{type HashGenerator}
import gleam/option.{type Option}
import gleam/result

pub type EntryScore {
  Exact(score: Int)
  LowerBound(score: Int)
  UpperBound(score: Int)
}

pub type TranspositionEntry {
  TranspositionEntry(
    encoding: Int,
    depth: Int,
    score: EntryScore,
    best_move: Option(Move),
  )
}

pub type TranspositionTable {
  TranspositionTable(
    generator: HashGenerator,
    table: USet(Int, TranspositionEntry),
  )
}

pub fn create_transposition(generator_seed seed: Int) {
  use table <- result.try(uset.new("Transposition", bravo.Public))

  TranspositionTable(generator: zobrist.create_hash(seed), table:)
  |> Ok()
}

pub fn delete_transposition(table: TranspositionTable) {
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
