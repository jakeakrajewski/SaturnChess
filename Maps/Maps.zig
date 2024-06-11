const std = @import("std");
const bit = @import("../BitManipulation/BitManipulation.zig");
const sqr = @import("../Board/Square.zig");

const Square = sqr.Square;

pub const NORTH: u8 = 8;
pub const SOUTH: u8 = -8;
pub const EAST: u8 = 1;
pub const WEST: u8 = -1;
pub const NORTHEAST: u8 = 9;
pub const NORTHWEST: u8 = 7;
pub const SOUTHEAST: u8 = -9;
pub const SOUTHWEST: u8 = -7;

pub const FILE_A: u64 = 72340172838076673;
pub const FILE_B: u64 = 144680345676153346;
pub const FILE_C: u64 = 289360691352306692;
pub const FILE_D: u64 = 578721382704613384;
pub const FILE_E: u64 = 1157442765409226768;
pub const FILE_F: u64 = 2314885530818453536;
pub const FILE_G: u64 = 4629771061636907072;
pub const FILE_H: u64 = 9259542123273814144;

pub const RANK_1: u64 = 18374686479671623680;
pub const RANK_2: u64 = 71776119061217280;
pub const RANK_3: u64 = 280375465082880;
pub const RANK_4: u64 = 1095216660480;
pub const RANK_5: u64 = 4278190080;
pub const RANK_6: u64 = 16711680;
pub const RANK_7: u64 = 65280;
pub const RANK_8: u64 = 255;

pub const DIAGONAL_A1H8: u64 = 9241421688590303745;
pub const DIAGONAL_H1A8: u64 = 18049651735527936;

pub const EDGE_MASK: u64 = 18411139144890810879; // FILE_A | FILE_H | RANK_1 | RANK_8

pub var pawnAttacks: [2][64]u64 = undefined;
pub var knightAttacks: [64]u64 = undefined;
pub var kingAttacks: [64]u64 = undefined;
pub var bishopMask: [64]u64 = undefined;
pub var rookMask: [64]u64 = undefined;

pub var bishopAttacks: [64][512]u64 = undefined;
pub var rookAttacks: [64][4096]u64 = undefined;
pub var queenAttacks: [64][4096]u64 = undefined;

pub const bishopRelevantBits: [64]u7 = .{ 6, 5, 5, 5, 5, 5, 5, 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 7, 7, 7, 7, 5, 5, 5, 5, 7, 9, 9, 7, 5, 5, 5, 5, 7, 9, 9, 7, 5, 5, 5, 5, 7, 7, 7, 7, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 5, 5, 5, 5, 5, 5, 6 };

pub const rookRelevantBits: [64]u7 = .{ 12, 11, 11, 11, 11, 11, 11, 12, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 11, 10, 10, 10, 10, 10, 10, 11, 12, 11, 11, 11, 11, 11, 11, 12 };
// rook magic numbers
pub const rook_magic_numbers: [64]u64 = .{
    0x8a80104000800020,
    0x140002000100040,
    0x2801880a0017001,
    0x100081001000420,
    0x200020010080420,
    0x3001c0002010008,
    0x8480008002000100,
    0x2080088004402900,
    0x800098204000,
    0x2024401000200040,
    0x100802000801000,
    0x120800800801000,
    0x208808088000400,
    0x2802200800400,
    0x2200800100020080,
    0x801000060821100,
    0x80044006422000,
    0x100808020004000,
    0x12108a0010204200,
    0x140848010000802,
    0x481828014002800,
    0x8094004002004100,
    0x4010040010010802,
    0x20008806104,
    0x100400080208000,
    0x2040002120081000,
    0x21200680100081,
    0x20100080080080,
    0x2000a00200410,
    0x20080800400,
    0x80088400100102,
    0x80004600042881,
    0x4040008040800020,
    0x440003000200801,
    0x4200011004500,
    0x188020010100100,
    0x14800401802800,
    0x2080040080800200,
    0x124080204001001,
    0x200046502000484,
    0x480400080088020,
    0x1000422010034000,
    0x30200100110040,
    0x100021010009,
    0x2002080100110004,
    0x202008004008002,
    0x20020004010100,
    0x2048440040820001,
    0x101002200408200,
    0x40802000401080,
    0x4008142004410100,
    0x2060820c0120200,
    0x1001004080100,
    0x20c020080040080,
    0x2935610830022400,
    0x44440041009200,
    0x280001040802101,
    0x2100190040002085,
    0x80c0084100102001,
    0x4024081001000421,
    0x20030a0244872,
    0x12001008414402,
    0x2006104900a0804,
    0x1004081002402,
};

// bishop magic numbers
pub const bishop_magic_numbers: [64]u64 = .{
    0x40040844404084,
    0x2004208a004208,
    0x10190041080202,
    0x108060845042010,
    0x581104180800210,
    0x2112080446200010,
    0x1080820820060210,
    0x3c0808410220200,
    0x4050404440404,
    0x21001420088,
    0x24d0080801082102,
    0x1020a0a020400,
    0x40308200402,
    0x4011002100800,
    0x401484104104005,
    0x801010402020200,
    0x400210c3880100,
    0x404022024108200,
    0x810018200204102,
    0x4002801a02003,
    0x85040820080400,
    0x810102c808880400,
    0xe900410884800,
    0x8002020480840102,
    0x220200865090201,
    0x2010100a02021202,
    0x152048408022401,
    0x20080002081110,
    0x4001001021004000,
    0x800040400a011002,
    0xe4004081011002,
    0x1c004001012080,
    0x8004200962a00220,
    0x8422100208500202,
    0x2000402200300c08,
    0x8646020080080080,
    0x80020a0200100808,
    0x2010004880111000,
    0x623000a080011400,
    0x42008c0340209202,
    0x209188240001000,
    0x400408a884001800,
    0x110400a6080400,
    0x1840060a44020800,
    0x90080104000041,
    0x201011000808101,
    0x1a2208080504f080,
    0x8012020600211212,
    0x500861011240000,
    0x180806108200800,
    0x4000020e01040044,
    0x300000261044000a,
    0x802241102020002,
    0x20906061210001,
    0x5a84841004010310,
    0x4010801011c04,
    0xa010109502200,
    0x4a02012000,
    0x500201010098b028,
    0x8040002811040900,
    0x28000010020204,
    0x6000020202d0240,
    0x8918844842082200,
    0x4010011029020020,
};

pub fn MaskPawnAttacks(square: u6, side: u1) !u64 {
    var bitboard: u64 = 0;

    var attacks: u64 = 0;

    bit.SetBit(&bitboard, try sqr.Square.fromIndex(@intCast(square)));

    if (side == 0) {
        if (((bitboard >> 7) & ~FILE_A) != 0) {
            attacks |= (bitboard >> 7);
        }
        if (((bitboard >> 9) & ~FILE_H) != 0) {
            attacks |= (bitboard >> 9);
        }
    } else {
        if (((bitboard << 7) & ~FILE_H) != 0) {
            attacks |= (bitboard << 7);
        }
        if (((bitboard << 9) & ~FILE_A) != 0) {
            attacks |= (bitboard << 9);
        }
    }

    return attacks;
}

pub fn MaskKnightAttacks(square: u6) !u64 {
    var bitboard: u64 = 0;
    var attacks: u64 = 0;

    bit.SetBit(&bitboard, try sqr.Square.fromIndex(@intCast(square)));
    if (((bitboard >> 17) & ~FILE_H) != 0) {
        attacks |= (bitboard >> 17);
    }
    if (((bitboard >> 15) & ~FILE_A) != 0) {
        attacks |= (bitboard >> 15);
    }
    if (((bitboard >> 10) & ~(FILE_G | FILE_H)) != 0) {
        attacks |= (bitboard >> 10);
    }
    if (((bitboard >> 6) & ~(FILE_A | FILE_B)) != 0) {
        attacks |= (bitboard >> 6);
    }
    if (((bitboard << 17) & ~FILE_A) != 0) {
        attacks |= (bitboard << 17);
    }
    if (((bitboard << 15) & ~FILE_H) != 0) {
        attacks |= (bitboard << 15);
    }
    if (((bitboard << 10) & ~(FILE_A | FILE_B)) != 0) {
        attacks |= (bitboard << 10);
    }
    if (((bitboard << 6) & ~(FILE_G | FILE_H)) != 0) {
        attacks |= (bitboard << 6);
    }

    return attacks;
}

pub fn MaskKingAttacks(square: u6) !u64 {
    var bitboard: u64 = 0;
    var attacks: u64 = 0;

    bit.SetBit(&bitboard, try sqr.Square.fromIndex(@intCast(square)));
    if ((bitboard >> 8) != 0) {
        attacks |= (bitboard >> 8);
    }
    if (((bitboard >> 9) & ~FILE_H) != 0) {
        attacks |= (bitboard >> 9);
    }
    if (((bitboard >> 1) & ~FILE_H) != 0) {
        attacks |= (bitboard >> 1);
    }
    if (((bitboard >> 7) & ~FILE_A) != 0) {
        attacks |= (bitboard >> 7);
    }
    if ((bitboard << 8) != 0) {
        attacks |= (bitboard << 8);
    }
    if (((bitboard << 9) & ~FILE_A) != 0) {
        attacks |= (bitboard << 9);
    }
    if (((bitboard << 1) & ~FILE_A) != 0) {
        attacks |= (bitboard << 1);
    }
    if (((bitboard << 7) & ~FILE_H) != 0) {
        attacks |= (bitboard << 7);
    }
    return attacks;
}

pub fn MaskBishopAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const rank = square / 8;
    const file = square % 8;

    var r = rank;
    var f = file;
    while (r < 7 and f < 7) : ({
        r += 1;
        f += 1;
    }) {
        attacks |= @as(u64, 1) << @intCast(r * 8 + f);
    }
    r = rank;
    f = file;
    while (r < 7 and f > 0) : ({
        r += 1;
        f -= 1;
    }) {
        attacks |= @as(u64, 1) << @intCast(r * 8 + f);
    }
    r = rank;
    f = file;
    while (r > 0 and f < 7) : ({
        r -= 1;
        f += 1;
    }) {
        attacks |= @as(u64, 1) << @intCast(r * 8 + f);
    }
    r = rank;
    f = file;
    while (r > 0 and f > 0) : ({
        r -= 1;
        f -= 1;
    }) {
        attacks |= @as(u64, 1) << @intCast(r * 8 + f);
    }

    attacks ^= (@as(u64, 1) << square);
    return attacks;
}

pub fn GenerateBishopAttacks(square: u6, blockers: u64) u64 {
    var attacks: u64 = 0;
    const rank = square / 8;
    const file = square % 8;
    var target: u64 = undefined;

    var r: i64 = rank;
    var f: i64 = file;
    while (r <= 7 and f <= 7) : ({
        r += 1;
        f += 1;
    }) {
        target = @as(u64, 1) << @intCast(r * 8 + f);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }
    r = rank;
    f = file;
    while (r <= 7 and f >= 0) : ({
        r += 1;
        f -= 1;
    }) {
        target = @as(u64, 1) << @intCast(r * 8 + f);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }
    r = rank;
    f = file;
    while (r >= 0 and f <= 7) : ({
        r -= 1;
        f += 1;
    }) {
        target = @as(u64, 1) << @intCast(r * 8 + f);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }
    r = rank;
    f = file;
    while (r >= 0 and f >= 0) : ({
        r -= 1;
        f -= 1;
    }) {
        target = @as(u64, 1) << @intCast(r * 8 + f);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }

    attacks ^= (@as(u64, 1) << square);
    return attacks;
}

pub fn MaskRookAttacks(square: u6) u64 {
    var attacks: u64 = 0;
    const rank: u8 = square / 8;
    const file: u8 = square % 8;

    for (1..7) |r| {
        if (r != rank) {
            attacks |= @as(u64, 1) << @intCast(r * 8 + file);
        }
    }

    for (1..7) |f| {
        if (f != file) {
            attacks |= @as(u64, 1) << @intCast(rank * 8 + f);
        }
    }

    return attacks;
}

pub fn GenerateRookAttacks(square: u6, blockers: u64) u64 {
    var attacks: u64 = 0;
    const rank = square / 8;
    const file = square % 8;
    var target: u64 = undefined;

    var r: i64 = rank;
    var f: i64 = file;
    while (r <= 7) : ({
        r += 1;
    }) {
        target = @as(u64, 1) << @intCast(r * 8 + file);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }
    r = rank;
    while (r >= 0) : ({
        r -= 1;
    }) {
        target = @as(u64, 1) << @intCast(r * 8 + file);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }
    r = rank;
    while (f <= 7) : ({
        f += 1;
    }) {
        target = @as(u64, 1) << @intCast(rank * 8 + f);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }
    f = file;
    while (f >= 0) : ({
        f -= 1;
    }) {
        target = @as(u64, 1) << @intCast(rank * 8 + f);
        attacks |= target;
        if ((target & blockers) != 0) break;
    }

    attacks ^= (@as(u64, 1) << square);
    return attacks;
}
pub fn GetBishopAttacks(square: u6, occupancy: u64) u64 {
    var occ = occupancy;
    occ &= bishopMask[square];
    occ *= bishop_magic_numbers[square];
    occ &= 0xffffffffffffffff;
    occ >>= @intCast(64 - bishopRelevantBits[square]);
    return bishopAttacks[square][occ];
}

pub fn GetRookAttacks(square: u6, occupancy: u64) u64 {
    var occ = occupancy;
    occ &= rookMask[square];
    occ *= rook_magic_numbers[square];
    occ &= 0xffffffffffffffff;
    occ >>= @intCast(64 - rookRelevantBits[square]);
    return rookAttacks[square][occ];
}

pub fn GenerateQueenAttacks(square: u6, blockers: u64) u64 {
    const rook = GetRookAttacks(square, blockers);
    const bishop = GetBishopAttacks(square, blockers);
    return rook | bishop;
}

pub fn GenerateLeaperAttacks() !void {
    for (0..64) |square| {
        const s: u6 = @intCast(square);
        pawnAttacks[0][square] = try MaskPawnAttacks(s, 0);
        pawnAttacks[1][square] = try MaskPawnAttacks(s, 1);
        knightAttacks[square] = try MaskKnightAttacks(s);
        kingAttacks[square] = try MaskKingAttacks(s);
    }
}

pub fn initBishopAttacks() void {
    for (0..64) |square| {
        const s: u6 = @intCast(square);
        const mask = MaskBishopAttacks(s);
        const bitCount = bishopRelevantBits[square];
        const permutations = @as(u64, 1) << @intCast(bitCount);

        for (0..permutations) |i| {
            const blockers = bit.setOccupancy(i, bitCount, mask);
            var magicIndex: u128 = blockers;
            magicIndex &= mask;
            magicIndex *= bishop_magic_numbers[s];
            magicIndex &= 0xffffffffffffffff;
            magicIndex >>= @intCast(64 - bitCount);
            bishopAttacks[square][@intCast(magicIndex)] = GenerateBishopAttacks(s, blockers);
        }
    }
}

pub fn initRookAttacks() void {
    for (0..64) |square| {
        const s: u6 = @intCast(square);
        const mask = MaskRookAttacks(s);
        const bitCount = rookRelevantBits[square];
        const permutations = @as(u64, 1) << @intCast(bitCount);

        for (0..permutations) |i| {
            const blockers = bit.setOccupancy(i, bitCount, mask);
            const magicIndex = ((@as(u128, blockers) * rook_magic_numbers[square]) & 0xffffffffffffffff) >> @intCast(64 - bitCount);
            rookAttacks[square][@intCast(magicIndex)] = GenerateRookAttacks(s, blockers);
        }
    }
}

pub fn InitializeAttackTables() !void {
    try GenerateLeaperAttacks();
    initRookAttacks();
    initBishopAttacks();
}
