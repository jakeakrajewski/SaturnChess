const std = @import("std");
const fen = @import("FenStrings.zig");
const brd = @import("Board.zig");
const move = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");

const Allocator = std.mem.Allocator;

pub fn perft(board: *brd.Board, list: *std.ArrayList(move.Move), startDepth: u8, depth: u8, side: u1, allocator: Allocator) !Position {
    const other_side: u1 = if (side == 0) 1 else 0;
    var moves = std.ArrayList(move.Move).init(list.allocator);
    defer moves.deinit();

    var pos: Position = Position{};

    try move.generateMoves(&moves, board, side);

    if (depth == 1) {
        for (0..moves.items.len) |i| {
            var start = try sqr.Square.FromIndex(moves.items[i].source);
            var end = try sqr.Square.FromIndex(moves.items[i].target);
            std.debug.print("\n     {s}{s} {}: ", .{ start.toString(), end.toString(), moves.items[i].isCapture });
        }
        pos.update(moves);
        return pos;
    }

    for (0..moves.items.len) |i| {
        var board_copy = board.*;
        const result = move.makeMove(moves.items[i], &board_copy, side);
        if (result) {
            const newPos = try perft(&board_copy, list, startDepth, depth - 1, other_side, allocator);
            pos.Nodes += newPos.Nodes;
            pos.Captures += newPos.Captures;
            pos.EnPassant += newPos.EnPassant;
            pos.Castles += newPos.Castles;
            pos.Promotions += newPos.Promotions;
            // pos.GenerationTime += newPos.GenerationTime;
            // pos.MakeTime += newPos.MakeTime;
            var start = try sqr.Square.FromIndex(moves.items[i].source);
            var end = try sqr.Square.FromIndex(moves.items[i].target);
            if (depth == startDepth) std.debug.print("\n     {s}{s}: {}", .{ start.toString(), end.toString(), newPos.Nodes });
        } else {
            const m = moves.items[i];
            var start = try sqr.Square.FromIndex(m.source);
            var end = try sqr.Square.FromIndex(m.target);
            std.debug.print("Piece: {}", .{m.piece});
            std.debug.print("Start: {s}", .{start.toString()});
            std.debug.print("End: {s}", .{end.toString()});
            bit.print(board.allPieces());
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

    pub fn update(self: *Position, moves: std.ArrayList(move.Move)) void {
        for (0..moves.items.len) |i| {
            self.Nodes += 1;
            if (moves.items[i].isCapture) self.Captures += 1;
            if (moves.items[i].isEnPassant) self.EnPassant += 1;
            if (moves.items[i].isCastle()) self.Castles += 1;
            if (moves.items[i].isPromotion()) self.Promotions += 1;
        }
    }
};
