const std = @import("std");
const sqr = @import("Square.zig");

pub fn getBit(bitBoard: u64, square: u6) u64 {
    return (bitBoard & (@as(u64, 1) << square));
}

pub fn setBit(bitBoard: *u64, square: u6) void {
    bitBoard.* |= (@as(u64, 1) << @as(u6, square));
}

pub fn popBit(bitBoard: *u64, square: u6) void {
    bitBoard.* &= ~(@as(u64, 1) << @as(u6, square));
}

pub fn popLSB(bitBoard: *u64) void {
    bitBoard.* &= (bitBoard.* - 1);
}

pub inline fn bitCount(bitboard: u128) u7 {
    var count: u6 = 0;
    var board = bitboard;

    while (board > 0) {
        board &= board - 1;
        count += 1;
    }

    return count;
}

pub inline fn leastSignificantBit(bitboard: u64) u7 {
    if (bitboard == 0) return 64;
    return (@ctz(bitboard));
}

pub fn setOccupancy(index: usize, relevantBits: u7, attackMask: u64) u64 {
    var blockers: u64 = 0;
    const bit_Set: u7 = relevantBits;
    var mask = attackMask;
    for (0..bit_Set) |i| {
        const square: u6 = @truncate(leastSignificantBit(mask));
        popBit(&mask, square);

        if ((index & (@as(u64, 1) << @intCast(i))) > 0) {
            blockers |= @as(u64, 1) << square;
        }
    }

    return blockers;
}

pub fn print(bitBoard: u64) void {
    std.debug.print("\n", .{});
    for (0..8) |rank| {
        for (0..8) |file| {
            const square: u6 = @intCast(rank * 8 + file);
            const r = 8 - rank;
            const bit: u64 = if (getBit(bitBoard, square) != 0) 1 else 0;
            if (file == 0) std.debug.print("  {d} ", .{r});
            std.debug.print(" {d}", .{bit});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("     A B C D E F G H \n", .{});
    std.debug.print("{d}", .{bitBoard});
}
