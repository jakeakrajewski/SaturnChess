const std = @import("std");
const sqr = @import("../Board/Square.zig");

var stdout = std.io.getStdOut().writer();

pub fn GetBit(bitBoard: u64, square: u6) u64 {
    return (bitBoard & (@as(u64, 1) << square));
}

pub fn SetBit(bitBoard: u64, square: sqr.Square) u64 {
    var board = bitBoard;
    board |= (@as(u64, 1) << @as(u6, square.toIndex()));
    return board;
}

pub fn PopBit(bitBoard: u64, square: sqr.Square) u64 {
    var board = bitBoard;
    board ^= (@as(u64, 1) << @as(u6, square.toIndex()));
    return if (GetBit(board, square.toIndex()) == 1) board else 0;
}

pub fn Print(bitBoard: u64) !void {
    try stdout.print("\n", .{});
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            const r = 8 - rank;
            const bit: u64 = if (GetBit(bitBoard, square) != 0) 1 else 0;
            try if (file == 0) stdout.print("  {d} ", .{r});
            try stdout.print(" {d}", .{bit});
        }
        try stdout.print("\n", .{});
    }

    try stdout.print("     A B C D E F G H \n", .{});
    try stdout.print("{d}", .{bitBoard});
}
