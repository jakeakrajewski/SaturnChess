const std = @import("std");
const map = @import("Maps.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const rand = @import("Rand.zig");
const brd = @import("Board.zig");
const fen = @import("FenStrings.zig");
const mv = @import("Moves.zig");
const perft = @import("Perft.zig");
const uci = @import("UCI.zig");
const eval = @import("Evaluate.zig");
const builtin = @import("builtin");
const zob = @import("Zobrist.zig");
const ser = @import("Search.zig");

pub fn main() !void {
    try map.initializeAttackTables();
    try uci.uciLoop();
    //
    // var board: brd.Board = undefined;
    // brd.setBoardFromFEN(fen.tricky_position, &board);
    // zob.generateHashKey(&board);
    // std.debug.print("\nKey 1: {}", .{board.hashKey});
    // // brd.setBoardFromFEN(fen.start_position, &board);
    // zob.generateHashKey(&board);
    // std.debug.print("\nKey 2: {}", .{board.hashKey});
    // zob.writeTT(board, &ser.transposition_tables, 100, 1, 8);
    // const score = zob.probeTT(board, &ser.transposition_tables, 8, -1000, 1000);
    //
    // std.debug.print("\nReturned Score: {}", .{score});
}
