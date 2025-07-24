const std = @import("std");
const map = @import("Maps.zig");
const sqr = @import("Square.zig");
const bit = @import("BitManipulation.zig");

const stdout = std.io.getStdOut().writer();

pub fn FindMagicNumber(square: u6, relevant_bits: u7, is_bishop: bool) u64 {
    const max_attempts: usize = 1000000;
    const occupancy_indices: usize = @as(usize, 1) << @intCast(relevant_bits);

    var occupancies: [4096]u64 = undefined;
    var attacks: [4096]u64 = undefined;
    var used_attacks: [4096]u64 = undefined;

    const mask = if (is_bishop) map.MaskBishopAttacks(square) else map.MaskRookAttacks(square);

    for (0..occupancy_indices) |index| {
        occupancies[index] = bit.SetOccupancy(index, relevant_bits, mask);
        attacks[index] = if (is_bishop) map.GenerateBishopAttacks(square, occupancies[index]) else map.GenerateRookAttacks(square, occupancies[index]);
    }
    var attempt: usize = 0;

    while (attempt < max_attempts) {
        const magic = GenerateMagicNumber();

        // Ignore unsuitable magic numbers
        if (bit.BitCount((@as(u128, mask) * magic) & 0xFF00000000000000) < 6) {
            continue;
        }

        @memset(&used_attacks, 0);

        var fail = false;
        for (0..occupancy_indices) |index| {
            const magic_index = ((@as(u128, occupancies[index]) * magic) & 0xffffffffffffffff) >> @intCast(64 - relevant_bits);
            if (used_attacks[@intCast(magic_index)] == 0) {
                used_attacks[@intCast(magic_index)] = attacks[index];
            } else if (used_attacks[@intCast(magic_index)] != attacks[index]) {
                fail = true;
                break;
            }
        }

        if (!fail) {
            return magic;
        }
        attempt += 1;
    }

    @panic("Failed to find magic number");
}

var state: u32 = 1804289383;

pub fn RandU32() u32 {
    var num: u32 = state;

    num ^= num << 13;
    num ^= num >> 17;
    num ^= num << 5;
    state = num;

    return state;
}

pub fn RandU64() u64 {
    var n1: u64 = @intCast(RandU32());
    var n2: u64 = @intCast(RandU32());
    var n3: u64 = @intCast(RandU32());
    var n4: u64 = @intCast(RandU32());

    n1 &= 0xFFFF;
    n2 &= 0xFFFF;
    n3 &= 0xFFFF;
    n4 &= 0xFFFF;

    return n1 | (n2 << 16) | (n3 << 32) | (n4 << 48);
}

pub fn GenerateMagicNumber() u64 {
    return RandU64() & RandU64() & RandU64();
}

pub fn InitMagicNumbers() !void {
    for (0..64) |square| {
        try stdout.print("{x}\n", .{FindMagicNumber(@intCast(square), map.bishopRelevantBits[square], true)});
    }
}
