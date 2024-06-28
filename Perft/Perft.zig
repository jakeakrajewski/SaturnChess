const std = @import("std");
const fen = @import("../Testing/FenStrings.zig");
const brd = @import("../Board/Board.zig");
const move = @import("../Moves/Moves.zig");

pub fn Perft(board: *brd.Board, depth: u8, side: u1) !u64 {
    var nodes: u64 = 0;
    const otherSide: u1 = if (side == 0) 1 else 0;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var moves = std.ArrayList(move.Move).init(allocator);
    try move.GenerateMoves(&moves, board, side);

    if (depth == 1) return @intCast(moves.items.len);

    for (0..moves.items.len) |i| {
        var cBoard = board.*;
        const result = move.MakeMove(moves.items[i], &cBoard, side);
        if (result) {
            nodes += try Perft(&cBoard, depth - 1, otherSide);
        } else {
            @panic("Illegal Move");
        }
    }
    return nodes;
}
