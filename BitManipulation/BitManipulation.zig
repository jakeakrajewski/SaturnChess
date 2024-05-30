const std = @import("std");
const sqr = @import("../Board/Square.zig");

var stdout = std.io.getStdOut().writer();

pub fn GetBit(bitBoard: u64, square: u6) u64 {
    return (bitBoard & (@as(u64, 1) << square));
}

pub fn SetBit(bitBoard: *u64, square: sqr.Square) void {
    bitBoard.* |= (@as(u64, 1) << @as(u6, square.toIndex()));
}

pub fn PopBit(bitBoard: *u64, square: sqr.Square) void {
    bitBoard.* ^= (@as(u64, 1) << @as(u6, square.toIndex()));
    if (GetBit(bitBoard.*, square.toIndex()) != 1) {
        bitBoard.* = 0;
    }
}

pub fn BitCount(bitboard: u64) u6 {
    var count: u6 = 0;
    var board = bitboard;

    while (board > 0) {
        board &= board - 1;
        count += 1;
    }

    return count;
}

pub fn LeastSignificantBit(bitboard: *u64) i6 {
    if (bitboard.* == 0) return -1;
    return @intCast(@ctz(bitboard.*));
}

pub fn SetOccupancy(index: usize, attackMask: *u64) u64 {
    var occupancy: u64 = 0;
    var count: usize = 0;

    for (0..64) |bitIndex| {
        if (GetBit(attackMask.*, @intCast(bitIndex)) != 0) {
            if (index & (@as(usize, 1) << @intCast(count)) != 0) {
                occupancy |= (@as(u64, 1) << @intCast(bitIndex));
            }
            count += 1;
        }
    }

    return occupancy;
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
