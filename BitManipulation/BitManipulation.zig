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
}

pub fn BitCount(bitboard: u128) u7 {
    var count: u6 = 0;
    var board = bitboard;

    while (board > 0) {
        board &= board - 1;
        count += 1;
    }

    return count;
}

pub fn LeastSignificantBit(bitboard: u64) u7 {
    if (bitboard == 0) return 64;
    return (@ctz(bitboard));
}

pub fn setOccupancy(index: usize, relevantBits: u7, attackMask: u64) u64 {
    var blockers: u64 = 0;
    const bitsSet: u7 = relevantBits;
    var mask = attackMask;
    for (0..bitsSet) |i| {
        const square: u6 = @truncate(LeastSignificantBit(mask));
        PopBit(&mask, try sqr.Square.fromIndex(square));

        if ((index & (@as(u64, 1) << @intCast(i))) > 0) {
            blockers |= @as(u64, 1) << square;
        }
    }

    return blockers;
}

pub fn Print(bitBoard: u64) void {
    std.debug.print("\n", .{});
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            const r = 8 - rank;
            const bit: u64 = if (GetBit(bitBoard, square) != 0) 1 else 0;
            if (file == 0) std.debug.print("  {d} ", .{r});
            std.debug.print(" {d}", .{bit});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("     A B C D E F G H \n", .{});
    std.debug.print("{d}", .{bitBoard});
}
