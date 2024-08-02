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

    // var board: brd.Board = undefined;
    // brd.setBoardFromFEN("6k1/8/1B1RN3/8/1Q1p4/4P3/1qnr4/b6K w - - 0 1", &board);
    //
    // const move: mv.Move = mv.Move{ .source = @intFromEnum(sqr.Square.B6), .target = @intFromEnum(sqr.Square.D4), .piece = .B, .isCapture = true };
    //
    // bit.print(board.allPieces());
    // std.debug.print("\n SEE: {}", .{ser.statickExchangeEvaluation(move, &board)});
}
