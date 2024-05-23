const std = @import("std");
const bit = @import("../BitManipulation/BitManipulation.zig");
const sqr = @import("../Board/Square.zig");

const Square = sqr.Square;

pub const FILE_A: u64 = 72340172838076673;
pub const FILE_B: u64 = 144680345676153346;
pub const FILE_C: u64 = 289360691352306692;
pub const FILE_D: u64 = 578721382704613384;
pub const FILE_E: u64 = 1157442765409226768;
pub const FILE_F: u64 = 2314885530818453536;
pub const FILE_G: u64 = 4629771061636907072;
pub const FILE_H: u64 = 9259542123273814144;

pub const RANK_8: u64 = 255;
pub const RANK_7: u64 = 65280;
pub const RANK_6: u64 = 16711680;
pub const RANK_5: u64 = 4278190080;
pub const RANK_4: u64 = 1095216660480;
pub const RANK_3: u64 = 280375465082880;
pub const RANK_2: u64 = 71776119061217280;
pub const RANK_1: u64 = 18374686479671623680;

pub var pawnAttacks: [2][64]u64 = undefined;
pub var knightAttacks: [64]u64 = undefined;
pub var kingAttacks: [64]u64 = undefined;

pub fn MaskPawnAttacks(square: Square, side: u1) u64 {
    var bitboard: u64 = 0;

    var attacks: u64 = 0;

    bitboard = bit.SetBit(bitboard, square);

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

pub fn MaskKnightAttacks(square: Square) u64 {
    var bitboard: u64 = 0;
    var attacks: u64 = 0;

    bitboard = bit.SetBit(bitboard, square);
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

pub fn MaskKingAttacks(square: Square) u64 {
    var bitboard: u64 = 0;
    var attacks: u64 = 0;

    bitboard = bit.SetBit(bitboard, square);
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

pub fn GenerateLeaperAttacks() void {
    for (0..64) |s| {
        pawnAttacks[0][s] = MaskPawnAttacks(0, s);
        pawnAttacks[1][s] = MaskPawnAttacks(1, s);
        knightAttacks[s] = MaskKnightAttacks(s);
        kingAttacks[s] = MaskKingAttacks(s);
    }
}
