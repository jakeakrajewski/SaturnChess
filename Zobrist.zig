const std = @import("std");
const sqr = @import("Square.zig");
const mv = @import("Moves.zig");
const brd = @import("Board.zig");
const bit = @import("BitManipulation.zig");
const fen = @import("FenStrings.zig");
const perft = @import("Perft.zig");
const search = @import("Search.zig");
const builtin = @import("builtin");
const rand = @import("Rand.zig");
const ser = @import("Search.zig");

pub var piece_keys: [12][64]u64 = undefined;
pub var enpassant_keys: [64]u64 = undefined;
pub var castle_keys: [16]u64 = undefined;
pub var side_key: u64 = undefined;
var seed: u32 = 1804289383;

pub const hash_size = 0x400000;

pub fn initHashKeys() void {
    for (0..12) |p| {
        for (0..64) |s| {
            piece_keys[p][s] = rand.RandU64();
            enpassant_keys[s] = rand.RandU64();
        }
    }

    for (0..16) |c| {
        castle_keys[c] = rand.RandU64();
    }

    side_key = rand.RandU64();
}

pub fn generateHashKey(board: *brd.Board) void {
    board.hashKey = 0;
    var bitboard: u64 = 0;
    var b = board.*;

    for (0..12) |p| {
        bitboard = b.getPieceBitBoard(brd.piece_array[p]).*;

        while (bitboard > 0) {
            const square: u6 = @intCast(bit.leastSignificantBit(bitboard));
            board.hashKey ^= piece_keys[p][square];
            bit.popBit(&bitboard, square);
        }

        if (board.enPassantSquare != 0) {
            board.hashKey ^= enpassant_keys[bit.leastSignificantBit(board.enPassantSquare)];
        }
    }

    board.hashKey ^= board.castle;

    if (board.sideToMove == 1) {
        board.hashKey ^= side_key;
    }
}

pub const HashType = enum(u2) { Exact = 0, Alpha = 1, Beta = 2 };
pub const TranspositionTable = struct {
    key: u64,
    depth: i32,
    flags: u2,
    score: i64,
};

pub fn probeTT(board: brd.Board, table: *[hash_size]TranspositionTable, depth: i8, alpha: i64, beta: i64) i64 {
    const entry = table[board.hashKey % hash_size];
    if (entry.key == board.hashKey) {
        if (entry.depth >= depth) {
            if (entry.flags == 0) {
                return entry.score;
            }
            if (entry.flags == 1 and entry.score <= alpha) {
                return alpha;
            }
            if (entry.flags == 2 and entry.score >= beta) {
                return beta;
            }
        }
    }
    return 100000;
}

pub fn writeTT(board: brd.Board, table: *[hash_size]TranspositionTable, score: i64, flags: u2, depth: i8) void {
    var entry = table[board.hashKey % hash_size];
    if (entry.depth > depth) return;
    entry.key = board.hashKey;
    entry.score = score;
    entry.depth = depth;
    entry.flags = flags;
    table[board.hashKey % hash_size] = entry;
}

pub fn clearTT() void {
    for (0..ser.transposition_tables.len) |t| {
        ser.transposition_tables[t].key = 0;
        ser.transposition_tables[t].depth = 0;
        ser.transposition_tables[t].flags = 0;
        ser.transposition_tables[t].score = 0;
    }
}
