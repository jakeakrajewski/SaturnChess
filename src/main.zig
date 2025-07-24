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
    // brd.setBoardFromFEN("2K5/8/8/3pRrRr/8/8/8/2k5 w - - 0 1", &board);
    //
    // const move: mv.Move = mv.Move{ .source = @intFromEnum(sqr.Square.E5), .target = @intFromEnum(sqr.Square.D5), .piece = .R, .isCapture = true };
    //
    // bit.print(board.allPieces());
    // std.debug.print("\n SEE: {}", .{ser.staticExchangeDriver(move, &board)});
}
