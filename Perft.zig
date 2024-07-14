const std = @import("std");
const fen = @import("FenStrings.zig");
const brd = @import("Board.zig");
const move = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");

const Allocator = std.mem.Allocator;

pub fn Perft(board: *brd.Board, list: std.ArrayList(move.Move), startDepth: u8, depth: u8, side: u1, allocator: Allocator) !Position {
    const otherSide: u1 = if (side == 0) 1 else 0;
    var moves = list;

    var pos: Position = Position{};

    // const generateStart = std.time.milliTimestamp();
    try move.GenerateMoves(&moves, board, side);
    // const generateEnd = std.time.milliTimestamp();
    // pos.GenerationTime = generateEnd - generateStart;

    if (depth == 1) {
        pos.Update(moves);
        return pos;
    }

    for (0..moves.items.len) |i| {
        // const makeStart = std.time.milliTimestamp();
        var cBoard = board.*;
        const result = move.MakeMove(moves.items[i], &cBoard, side);
        // const makeEnd = std.time.milliTimestamp();
        // pos.MakeTime += makeEnd - makeStart;
        if (result) {
            const newPos = try Perft(&cBoard, list, startDepth, depth - 1, otherSide, allocator);
            pos.Nodes += newPos.Nodes;
            pos.Captures += newPos.Captures;
            pos.EnPassant += newPos.EnPassant;
            pos.Castles += newPos.Castles;
            pos.Promotions += newPos.Promotions;
            // pos.GenerationTime += newPos.GenerationTime;
            // pos.MakeTime += newPos.MakeTime;
            var start = try sqr.Square.fromIndex(moves.items[i].source);
            var end = try sqr.Square.fromIndex(moves.items[i].target);
            if (depth == startDepth) std.debug.print("\n     {s}{s}: {}", .{ start.toString(), end.toString(), newPos.Nodes });
        } else {
            const m = moves.items[i];
            var start = try sqr.Square.fromIndex(m.source);
            var end = try sqr.Square.fromIndex(m.target);
            std.debug.print("Piece: {}", .{m.piece});
            std.debug.print("Start: {s}", .{start.toString()});
            std.debug.print("End: {s}", .{end.toString()});
            bit.Print(board.allPieces());
            @panic("Illegal Move");
        }
    }
    return pos;
}

pub const Position = struct {
    Nodes: u64 = 0,
    Captures: u64 = 0,
    EnPassant: u64 = 0,
    Castles: u64 = 0,
    Promotions: u64 = 0,
    // GenerationTime: i64 = 0,
    MakeTime: i64 = 0,

    pub fn Update(self: *Position, moves: std.ArrayList(move.Move)) void {
        for (0..moves.items.len) |i| {
            self.Nodes += 1;
            if (moves.items[i].isCapture) self.Captures += 1;
            if (moves.items[i].isEnPassant) self.EnPassant += 1;
            if (moves.items[i].isCastle()) self.Castles += 1;
            if (moves.items[i].isPromotion()) self.Promotions += 1;
        }
    }
};
