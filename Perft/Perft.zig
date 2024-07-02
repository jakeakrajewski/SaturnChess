const std = @import("std");
const fen = @import("../Testing/FenStrings.zig");
const brd = @import("../Board/Board.zig");
const move = @import("../Moves/Moves.zig");
const bit = @import("../BitManipulation/BitManipulation.zig");
const sqr = @import("../Board/Square.zig");

pub fn Perft(board: *brd.Board, depth: u8, side: u1) !Position {
    const otherSide: u1 = if (side == 0) 1 else 0;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var moves = std.ArrayList(move.Move).init(allocator);
    try move.GenerateMoves(&moves, board, side);

    var pos: Position = Position{};

    if (depth == 1) {
        pos.Update(moves);
        return pos;
    }

    for (0..moves.items.len) |i| {
        var cBoard = board.*;
        const result = move.MakeMove(moves.items[i], &cBoard, side);
        if (result) {
            const newPos = try Perft(&cBoard, depth - 1, otherSide);
            pos.Nodes += newPos.Nodes;
            pos.Captures += newPos.Captures;
            pos.EnPassant += newPos.EnPassant;
            pos.Castles += newPos.Castles;
            pos.Promotions += newPos.Promotions;
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
