const std = @import("std");
const map = @import("../Maps/Maps.zig");
const sqr = @import("../Board/Square.zig");
const bitManip = @import("../BitManipulation/BitManipulation.zig");

const stdout = std.io.getStdOut().writer();

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

pub fn FindMagicNumber(square: u32, relevantBits: u32, bishop: u64) !u64 {
    var occupancies: [4096]u64 = undefined;
    var attacks: [4096]u64 = undefined;
    var usedAttacks: [4096]u64 = undefined;
    const s = try sqr.Square.fromIndex(@intCast(square));
    var attackMask = if (bishop == 1) map.MaskBishopAttacks(s) else map.MaskRookAttacks(s);

    const occupancyIndecies = @as(u64, 1) << @intCast(relevantBits);

    for (0..occupancyIndecies) |index| {
        occupancies[index] = bitManip.SetOccupancy(index, &attackMask);

        attacks[index] = if (bishop == 1) map.GenerateBishopAttacks(s, occupancies[index]) else map.GenerateRookAttacks(s, occupancies[index]);
    }

    var randCount: u64 = 0;
    while (randCount < 1000000000) {
        const magicNumber = GenerateMagicNumber();
        const product = @mulWithOverflow(magicNumber, attackMask);

        if (bitManip.BitCount(product[0] & 0xFF00000000000000) < 6) continue;

        @memset(&usedAttacks, 0);

        var index: i32 = 0;
        var fail: i32 = 0;

        while (fail != 1 and index < occupancyIndecies) {
            const p = @mulWithOverflow(occupancies[@intCast(index)], magicNumber);
            const magicIndex: usize = @as(usize, @intCast(p[0])) >> @intCast(64 - relevantBits);

            if (usedAttacks[magicIndex] == @as(u64, 0)) {
                usedAttacks[magicIndex] = attacks[@intCast(index)];
            } else if (usedAttacks[magicIndex] != attacks[@intCast(index)]) {
                fail = 1;
            }

            index += 1;
        }

        if (fail != 0) {
            return magicNumber;
        }

        randCount += 1;
    }
    unreachable;
}

pub fn InitMagicNumbers() !void {
    for (0..64) |square| {
        try stdout.print("{x}\n", .{try FindMagicNumber(@intCast(square), map.rookRelevantBits[square], 0)});
    }
}
