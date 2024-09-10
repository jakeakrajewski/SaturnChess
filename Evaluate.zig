const std = @import("std");
const map = @import("Maps.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const rand = @import("Rand.zig");
const brd = @import("Board.zig");
const fen = @import("FenStrings.zig");
const mv = @import("Moves.zig");
const perft = @import("Perft.zig");
const uci = @import("UCI.zig");

const mid_game_material_score = []u16{ 100, 700, 800, 1200, 2500, 10000 };
const end_game_material_score = []u16{ 200, 800, 900, 1300, 2700, 10000 };
var phase: f32 = 0.0;
var end_game: bool = false;
pub var board: brd.Board = undefined;

pub inline fn evaluate(b: brd.Board) i64 {
    board = b;
    end_game = isEndGame(b);
    var score: i64 = 0;
    phase = gamePhase();

    const mid_game_material: f32 = @floatFromInt(materialScoreMG());
    const end_game_material: f32 = @floatFromInt(materialScoreEG());
    const material_score: i64 = @intFromFloat(phase * end_game_material + (1.0 - phase) * mid_game_material);
    score += material_score;
    score += scorePawns(0) - scorePawns(1);
    score += pawnSquareScore();
    score += scorePieces();
    score += space();
    return if (board.sideToMove == 0) score else -score;
}

pub inline fn materialCount() i64 {
    return bit.bitCount(board.allPieces() ^ (board.wPawns | board.bPawns)) - 2;
}
pub inline fn nonPawnMaterialValue() i64 {
    var score: i64 = 0;

    score += 300 * (@as(i64, bit.bitCount(board.wKnights)) + bit.bitCount(board.bKnights));
    score += 300 * (@as(i64, bit.bitCount(board.wBishops)) + bit.bitCount(board.bBishops));
    score += 500 * (@as(i64, bit.bitCount(board.wRooks)) + bit.bitCount(board.bRooks));
    score += 900 * (@as(i64, bit.bitCount(board.wQueens)) + bit.bitCount(board.bQueens));

    return score;
}

pub inline fn isEndGame(b: brd.Board) bool {
    board = b;
    if (materialCount() <= 7) return true else return false;
}

pub inline fn gamePhase() f32 {
    const material: f32 = @floatFromInt(nonPawnMaterialValue());
    const max_material: f32 = 6200;
    const end_game_cutoff: f32 = 3800;

    if (material < end_game_cutoff) return 1.0;

    // Cast to f32 to perform floating-point division
    return 1.0 - (material - end_game_cutoff) / (max_material - end_game_cutoff);
}

pub inline fn materialScoreMG() i64 {
    var score: i64 = 0;

    score += 100 * (@as(i64, bit.bitCount(board.wPawns)) - bit.bitCount(board.bPawns));
    score += 700 * (@as(i64, bit.bitCount(board.wKnights)) - bit.bitCount(board.bKnights));
    score += 800 * (@as(i64, bit.bitCount(board.wBishops)) - bit.bitCount(board.bBishops));
    score += 1200 * (@as(i64, bit.bitCount(board.wRooks)) - bit.bitCount(board.bRooks));
    score += 2500 * (@as(i64, bit.bitCount(board.wQueens)) - bit.bitCount(board.bQueens));
    score += 10000 * (@as(i64, bit.bitCount(board.wKing)) - bit.bitCount(board.bKing));

    return score;
}

pub inline fn materialScoreEG() i64 {
    var score: i64 = 0;

    score += 200 * (@as(i64, bit.bitCount(board.wPawns)) - bit.bitCount(board.bPawns));
    score += 800 * (@as(i64, bit.bitCount(board.wKnights)) - bit.bitCount(board.bKnights));
    score += 900 * (@as(i64, bit.bitCount(board.wBishops)) - bit.bitCount(board.bBishops));
    score += 1300 * (@as(i64, bit.bitCount(board.wRooks)) - bit.bitCount(board.bRooks));
    score += 2700 * (@as(i64, bit.bitCount(board.wQueens)) - bit.bitCount(board.bQueens));
    score += 10000 * (@as(i64, bit.bitCount(board.wKing)) - bit.bitCount(board.bKing));

    return score;
}

const passed_pawn_score: [8]i64 = [8]i64{ 0, 10, 30, 50, 75, 100, 150, 200 };

pub inline fn pawnSquareScore() i64 {
    var score: i64 = 0;
    var white_pawns = board.wPawns;
    var black_pawns = board.bPawns;
    while (white_pawns > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(white_pawns));
        bit.popBit(&white_pawns, (@intCast(square)));
        const rank = 7 - square / 8;
        // Passed Pawns
        var passed_mask = map.getSquareFile(square);
        if (square % 8 > 0) passed_mask |= map.getSquareFile(square - 1);
        if (square % 8 < 7) passed_mask |= map.getSquareFile(square + 1);
        const board_ahead = ~@as(u64, 0) >> 63 - square;
        if (board.bPawns & passed_mask & board_ahead == 0) {
            score += passed_pawn_score[rank];
        }
        // Piece Square Value
        score += pawn_mg_psv[square];
    }
    while (black_pawns > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(black_pawns));
        bit.popBit(&black_pawns, (@intCast(square)));
        const rank = 7 - square / 8;
        // Black Passed Pawns
        var passed_mask = map.getSquareFile(square);
        if (square % 8 > 0) passed_mask |= map.getSquareFile(square - 1);
        if (square % 8 < 7) passed_mask |= map.getSquareFile(square + 1);
        const board_ahead = ~@as(u64, 0) << square;
        if (board.wPawns & passed_mask & board_ahead == 0) {
            score -= passed_pawn_score[7 - rank];
        }
        // Black Piece Square Value
        score -= pawn_mg_psv[mirrorIndex(square)];
    }

    return score;
}

pub fn mirrorIndex(index: u6) u6 {
    const file = index % 8;
    const rank = index / 8;
    const mirrored_rank = 7 - rank;
    return file + mirrored_rank * 8;
}

// zig fmt: off

const pawn_mg_psv: [64]i64 = .{
      0,   0,   0,   0,   0,   0,  0,   0,
     98, 134,  61,  95,  68, 126, 34, -11,
     -6,   7,  26,  31,  65,  56, 25, -20,
    -14,  13,   6,  21,  23,  12, 17, -23,
    -27,  -2,  -5,  12,  17,   6, 10, -25,
    -26,  -4,  -4, -10,   3,   3, 33, -12,
    -35,  -1, -20, -23, -15,  24, 38, -22,
      0,   0,   0,   0,   0,   0,  0,   0,
};

const pawn_eg_psv: [64]i64 = .{
      0,   0,   0,   0,   0,   0,   0,   0,
    178, 173, 158, 134, 147, 132, 165, 187,
     94, 100,  85,  67,  56,  53,  82,  84,
     32,  24,  13,   5,  -2,   4,  17,  17,
     13,   9,  -3,  -7,  -7,  -8,   3,  -1,
      4,   7,  -6,   1,   0,  -5,  -1,  -8,
     13,   8,   8,  10,  13,   0,   2,  -7,
      0,   0,   0,   0,   0,   0,   0,   0,
};


const knight_mg_psv: [64]i64 = .{
    -167, -89, -34, -49,  61, -97, -15, -107,
     -73, -41,  72,  36,  23,  62,   7,  -17,
     -47,  60,  37,  65,  84, 129,  73,   44,
      -9,  17,  19,  53,  37,  69,  18,   22,
     -13,   4,  16,  13,  28,  19,  21,   -8,
     -23,  -9,  12,  10,  19,  17,  25,  -16,
     -29, -53, -12,  -3,  -1,  18, -14,  -19,
    -105, -21, -58, -33, -17, -28, -19,  -23,
};

const knight_eg_psv: [64]i64 = .{
    -58, -38, -13, -28, -31, -27, -63, -99,
    -25,  -8, -25,  -2,  -9, -25, -24, -52,
    -24, -20,  10,   9,  -1,  -9, -19, -41,
    -17,   3,  22,  22,  22,  11,   8, -18,
    -18,  -6,  16,  25,  16,  17,   4, -18,
    -23,  -3,  -1,  15,  10,  -3, -20, -22,
    -42, -20, -10,  -5,  -2, -20, -23, -44,
    -29, -51, -23, -15, -22, -18, -50, -64,
};


const bishop_mg_psv: [64]i64 = .{
    -29,   4, -82, -37, -25, -42,   7,  -8,
    -26,  16, -18, -13,  30,  59,  18, -47,
    -16,  37,  43,  40,  35,  50,  37,  -2,
     -4,   5,  19,  50,  37,  37,   7,  -2,
     -6,  13,  13,  26,  34,  12,  10,   4,
      0,  15,  15,  15,  14,  27,  18,  10,
      4,  15,  16,   0,   7,  21,  33,   1,
    -33,  -3, -14, -21, -13, -12, -39, -21,
};

const bishop_eg_psv: [64]i64 = .{
    -14, -21, -11,  -8, -7,  -9, -17, -24,
     -8,  -4,   7, -12, -3, -13,  -4, -14,
      2,  -8,   0,  -1, -2,   6,   0,   4,
     -3,   9,  12,   9, 14,  10,   3,   2,
     -6,   3,  13,  19,  7,  10,  -3,  -9,
    -12,  -3,   8,  10, 13,   3,  -7, -15,
    -14, -18,  -7,  -1,  4,  -9, -15, -27,
    -23,  -9, -23,  -5, -9, -16,  -5, -17,
};



const rook_mg_psv: [64]i64 = .{
     32,  42,  32,  51, 63,  9,  31,  43,
     27,  32,  58,  62, 80, 67,  26,  44,
     -5,  19,  26,  36, 17, 45,  61,  16,
    -24, -11,   7,  26, 24, 35,  -8, -20,
    -36, -26, -12,  -1,  9, -7,   6, -23,
    -45, -25, -16, -17,  3,  0,  -5, -33,
    -44, -16, -20,  -9, -1, 11,  -6, -71,
    -19, -13,   1,  17, 16,  7, -37, -26,
};

const rook_eg_psv: [64]i64 = .{
    13, 10, 18, 15, 12,  12,   8,   5,
    11, 13, 13, 11, -3,   3,   8,   3,
     7,  7,  7,  5,  4,  -3,  -5,  -3,
     4,  3, 13,  1,  2,   1,  -1,   2,
     3,  5,  8,  4, -5,  -6,  -8, -11,
    -4,  0, -5, -1, -7, -12,  -8, -16,
    -6, -6,  0,  2, -9,  -9, -11,  -3,
    -9,  2,  3, -1, -5, -13,   4, -20,
};

const king_mg_psv: [64]i64 = .{
    -65,  23,  16, -15, -56, -34,   2,  13,
     29,  -1, -20,  -7,  -8,  -4, -38, -29,
     -9,  24,   2, -16, -20,   6,  22, -22,
    -17, -20, -12, -27, -30, -25, -14, -36,
    -49,  -1, -27, -39, -46, -44, -33, -51,
    -14, -14, -22, -46, -44, -30, -15, -27,
      1,   7,  -8, -64, -43, -16,   9,   8,
    -15,  36,  12, -54,   8, -28,  24,  14,
};

const king_eg_psv: [64]i64 = .{
    -74, -35, -18, -18, -11,  15,   4, -17,
    -12,  17,  14,  17,  17,  38,  23,  11,
     10,  17,  23,  15,  20,  45,  44,  13,
     -8,  22,  24,  27,  26,  33,  26,   3,
    -18,  -4,  21,  24,  27,  23,   9, -11,
    -19,  -3,  11,  21,  23,  16,   7,  -9,
    -27, -11,   4,  13,  14,   4,  -5, -17,
    -53, -34, -21, -11, -28, -14, -24, -43
};

// zig fmt: on

pub fn scorePawns(side: u1) i64 {
    var score: i64 = 0;
    const pawns = if (side == 0) board.wPawns else board.bPawns;
    const opponent_pawns = if (side == 0) board.bPawns else board.wPawns;
    score -= 10 * countIsolatedPawns(pawns);
    score -= 5 * countBackwardPawns(pawns, opponent_pawns, side);
    score -= 10 * (bit.bitCount(getDoubledPawns(pawns)));
    score += 2 * countConnectedPawns(pawns);
    // score += 10 * (bit.bitCount(getPassedPawns(pawns, opponent_pawns, board.sideToMove)));
    return score;
}

pub fn countIsolatedPawns(pawns: u64) u8 {
    var num_isolated: u8 = 0;

    for (0..8) |f| {
        const file = map.files[f];
        if (pawns & file > 0) {
            if (f > 0 and f < 7) {
                if ((map.files[f - 1] | map.files[f + 1]) & pawns == 0) {
                    num_isolated += 1;
                }
            } else {
                if (f == 0 and map.files[1] & pawns == 0) {
                    num_isolated += 1;
                } else if (f == 7 and map.files[6] & pawns == 0) {
                    num_isolated += 1;
                }
            }
        }
    }

    return num_isolated;
}

pub fn getDoubledPawns(pawns: u64) u64 {
    const shiftedPawns = pawns << 8;
    const doubledPawns = pawns & shiftedPawns;
    return doubledPawns;
}

pub fn countConnectedPawns(pawns: u64) u8 {
    var pawn_mask = pawns;
    var connected_count: u8 = 0;

    while (pawn_mask > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(pawn_mask));
        const file = map.getSquareFile(square);
        bit.popBit(&pawn_mask, (@intCast(square)));

        const connected_area = try map.maskKingAttacks(square) & ~file;
        if (connected_area & pawns > 0) {
            connected_count += 1;
        }
    }

    return connected_count;
}

pub fn countBackwardPawns(ownPawns: u64, enemyPawns: u64, side: u1) u8 {
    const notAFile: u64 = 0xfefefefefefefefe;
    const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
    const isWhite: bool = side == 0;

    if (isWhite) {
        const enemyAttacks = (enemyPawns << 7 & notAFile) | (enemyPawns << 9 & notHFile);
        var pawn_mask = ownPawns;
        var backward_count: u8 = 0;

        while (pawn_mask > 0) {
            const square: u6 = @intCast(bit.leastSignificantBit(pawn_mask));
            const pawn_table = @as(u64, 1) << square;
            const file = map.getSquareFile(square);
            const forward_rank = map.getSquareRank(square + 8);
            bit.popBit(&pawn_mask, (@intCast(square)));

            const forward_area = try map.maskKingAttacks(square) & ~file & forward_rank;
            const backward_area = try map.maskKingAttacks(square) & ~file & ~forward_rank;

            if (forward_area & ownPawns > 0 and backward_area & ownPawns == 0) {
                if ((enemyAttacks << 8) & pawn_table > 0) {
                    backward_count += 1;
                }
            }
        }

        return backward_count;
    } else {
        const enemyAttacks = (enemyPawns >> 7 & notHFile) | (enemyPawns >> 9 & notAFile);

        var pawn_mask = ownPawns;
        var backward_count: u8 = 0;

        while (pawn_mask > 0) {
            const square: u6 = @intCast(bit.leastSignificantBit(pawn_mask));
            const pawn_table = @as(u64, 1) << square;
            const file = map.getSquareFile(square);
            const forward_rank = map.getSquareRank(square - 8);
            bit.popBit(&pawn_mask, (@intCast(square)));

            const forward_area = try map.maskKingAttacks(square) & ~file & forward_rank;
            const backward_area = try map.maskKingAttacks(square) & ~file & ~forward_rank;

            if (forward_area & ownPawns > 0 and backward_area & ownPawns == 0) {
                if ((enemyAttacks >> 8) & pawn_table > 0) {
                    backward_count += 1;
                }
            }
        }

        return backward_count;
    }
}

pub fn scorePieces() i64 {
    var score: i64 = 0;
    var b = board;

    const white_king_square: u6 = @intCast(bit.leastSignificantBit(board.wKing));
    const black_king_square: u6 = @intCast(bit.leastSignificantBit(board.bKing));

    while (b.wKnights > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wKnights));
        bit.popBit(&b.wKnights, (@intCast(square)));
        //Knight PSV
        const mg_psqt: f32 = @floatFromInt(knight_mg_psv[square]);
        const eg_psqt: f32 = @floatFromInt(knight_eg_psv[square]);
        const psqt_score: i64 = @intFromFloat(phase * eg_psqt + (1.0 - phase) * mg_psqt);
        score += psqt_score;
    }
    while (b.wBishops > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wBishops));
        bit.popBit(&b.wBishops, (@intCast(square)));
        // Bishop Targeting King Ring
        const attack_mask = map.getBishopAttacks(square, board.allPieces());
        if (attack_mask & map.king_attacks[black_king_square] > 0) score += 5;
        // Bishop Mobility
        score += 1 * (bit.bitCount(attack_mask));
        // Bishop Piece Square Value
        const mg_psqt: f32 = @floatFromInt(bishop_mg_psv[square]);
        const eg_psqt: f32 = @floatFromInt(bishop_eg_psv[square]);
        const psqt_score: i64 = @intFromFloat(phase * eg_psqt + (1.0 - phase) * mg_psqt);
        score += psqt_score;
    }
    while (b.wRooks > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wRooks));
        bit.popBit(&b.wRooks, (@intCast(square)));
        // Rook Targeting King Ring
        const attack_mask = map.getRookAttacks(square, board.allPieces());
        if (attack_mask & map.king_attacks[black_king_square] > 0) score += 15;
        // Rook on (Any) Queen File
        const file = map.getSquareFile(square);
        if (file & (board.wQueens | board.bQueens) > 0) score += 5;
        // Rook on Semi-Open or Open File
        score += if (file & board.wPawns & board.bPawns == 0) 50 else if (file & board.wPawns == 0) 15 else 0;
        score += 1 * (bit.bitCount(attack_mask));
        // Rook Piece Square Value

        const mg_psqt: f32 = @floatFromInt(rook_mg_psv[square]);
        const eg_psqt: f32 = @floatFromInt(rook_eg_psv[square]);
        const psqt_score: i64 = @intFromFloat(phase * eg_psqt + (1.0 - phase) * mg_psqt);
        score += psqt_score;
    }
    while (b.wQueens > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wQueens));
        bit.popBit(&b.wQueens, (@intCast(square)));
        // Queen Piece Square Value
        score += 1 * (bit.bitCount(map.generateQueenAttacks(square, board.allPieces())));
    }
    while (b.bKnights > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bKnights));
        bit.popBit(&b.bKnights, (@intCast(square)));
        // Black Knight PSV
        const mg_psqt: f32 = @floatFromInt(knight_mg_psv[mirrorIndex(square)]);
        const eg_psqt: f32 = @floatFromInt(knight_eg_psv[mirrorIndex(square)]);
        const psqt_score: i64 = @intFromFloat(phase * eg_psqt + (1.0 - phase) * mg_psqt);
        score -= psqt_score;
    }
    while (b.bBishops > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bBishops));
        bit.popBit(&b.bBishops, (@intCast(square)));
        // Black Bishop Targeting King Ring
        const attack_mask = map.getBishopAttacks(square, board.allPieces());
        if (attack_mask & map.king_attacks[white_king_square] > 0) score -= 5;
        // Black Bishop Mobility
        score -= 1 * (bit.bitCount(attack_mask));
        // Black Bishop Piece Square Values
        const mg_psqt: f32 = @floatFromInt(bishop_mg_psv[mirrorIndex(square)]);
        const eg_psqt: f32 = @floatFromInt(bishop_eg_psv[mirrorIndex(square)]);
        const psqt_score: i64 = @intFromFloat(phase * eg_psqt + (1.0 - phase) * mg_psqt);
        score -= psqt_score;
    }
    while (b.bRooks > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bRooks));
        bit.popBit(&b.bRooks, (@intCast(square)));
        // Black Rook Targeting King Ring
        const attack_mask = map.getRookAttacks(square, board.allPieces());
        if (attack_mask & map.king_attacks[white_king_square] > 0) score -= 15;
        // Black Rook on (Any) Queen File
        const file = map.getSquareFile(square);
        if (file & (board.wQueens | board.bQueens) > 0) score -= 5;
        // Black Rook on Semi-Open or Open File
        score -= if (file & board.wPawns & board.bPawns == 0) 50 else if (file & board.bPawns == 0) 15 else 0;
        score -= 1 * (bit.bitCount(attack_mask));
        // Black Rook Piece Square Value
        const mg_psqt: f32 = @floatFromInt(rook_mg_psv[mirrorIndex(square)]);
        const eg_psqt: f32 = @floatFromInt(rook_eg_psv[mirrorIndex(square)]);
        const psqt_score: i64 = @intFromFloat(phase * eg_psqt + (1.0 - phase) * mg_psqt);
        score -= psqt_score;
    }
    while (b.bQueens > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bQueens));
        bit.popBit(&b.bQueens, (@intCast(square)));
        // Black Queen Piece Square Value
        score -= 1 * (bit.bitCount(map.generateQueenAttacks(square, board.allPieces())));
    }

    const white_minor_behind_pawns = 20 * bit.bitCount((b.wPawns << 8) & (b.wKnights | b.wBishops));
    const black_minor_behind_pawns = 20 * bit.bitCount((b.bPawns >> 8) & (b.bKnights | b.bBishops));
    score += white_minor_behind_pawns - black_minor_behind_pawns;

    // Bishop Pair Imbalance
    const white_bishop_pair = bit.bitCount(board.wBishops) > 1;
    const black_bishop_pair = bit.bitCount(board.bBishops) > 1;

    if (white_bishop_pair and !black_bishop_pair) {
        score += 15;
    } else if (black_bishop_pair and !white_bishop_pair) {
        score -= 15;
    }

    // Bishops On Long Diagonals
    score += 40 * bit.bitCount(board.wBishops & (map.a1_diagonal | map.h1_diagonal));
    score -= 40 * bit.bitCount(board.bBishops & (map.a1_diagonal | map.h1_diagonal));

    // King Piece Square Value
    score += if (end_game) king_eg_psv[white_king_square] else king_mg_psv[white_king_square];
    // King Safety
    score += 1 * bit.bitCount(map.king_attacks[white_king_square] & board.wPieces());
    // King Piece On Semi-Open or Open File (deduction)
    const white_king_file = map.getSquareFile(white_king_square);
    score -= if (white_king_file & board.wPawns & board.bPawns == 0) 15 else if (white_king_file & board.wPawns == 0) 10 else 0;

    // Black King Piece Square Value
    score -= if (end_game) king_eg_psv[mirrorIndex(black_king_square)] else king_mg_psv[mirrorIndex(black_king_square)];
    // Black King Safety
    score -= 1 * bit.bitCount(map.king_attacks[black_king_square] & board.bPieces());
    // Black King Piece On Semi-Open or Open File (deduction)
    const black_king_file = map.getSquareFile(black_king_square);
    score += if (black_king_file & board.wPawns & board.bPawns == 0) 15 else if (black_king_file & board.wPawns == 0) 10 else 0;

    return score;
}

pub fn space() i64 {
    if (isEndGame(board)) return 0;
    const white_pieces = bit.bitCount(board.wPieces());
    const black_pieces = bit.bitCount(board.bPieces());
    var white_pawns = board.wPawns;
    var black_pawns = board.bPawns;
    var white_blocked: i64 = 0;
    var black_blocked: i64 = 0;

    while (white_pawns > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(white_pawns));
        bit.popBit(&white_pawns, (@intCast(square)));
        const source_board = @as(u64, 1) << square;
        if (board.bPawns & source_board >> 8 > 0 or board.bPawns & source_board >> 15 > 0 and board.bPawns & source_board >> 17 > 0) white_blocked += 1;
    }

    while (black_pawns > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(black_pawns));
        bit.popBit(&black_pawns, (@intCast(square)));
        const source_board = @as(u64, 1) << square;
        if (board.wPawns & source_board << 8 > 0 or board.wPawns & source_board << 15 > 0 and board.wPawns & source_board << 17 > 0) black_blocked += 1;
    }

    const white_weight = white_pieces - 3 + @min(white_blocked, 9);
    const black_weight = black_pieces - 3 + @min(black_blocked, 9);
    const white_score = @divTrunc(whiteSafeZone() * white_weight * white_weight, 16);
    const black_score = @divTrunc(blackSafeZone() * black_weight * black_weight, 16);

    return white_score - black_score;
}

pub fn whiteSafeZone() i64 {
    const white_center = (map.RANK_2 | map.RANK_3 | map.RANK_4) & (map.FILE_C | map.FILE_D | map.FILE_E | map.FILE_F);

    var white_safe_squares: u64 = white_center;
    white_safe_squares ^= board.bPawns << 7;
    white_safe_squares ^= board.bPawns << 9;

    var white_behind: u64 = 0;
    white_behind |= white_center & board.wPawns << 8;
    white_behind |= white_center & board.wPawns << 16;
    white_behind |= white_center & board.wPawns << 24;

    return @intCast(bit.bitCount(white_safe_squares) + bit.bitCount(white_behind));
}

pub fn blackSafeZone() i64 {
    const black_center = (map.RANK_5 | map.RANK_6 | map.RANK_7) & (map.FILE_C | map.FILE_D | map.FILE_E | map.FILE_F);

    var black_safe_squares: u64 = black_center;
    black_safe_squares ^= board.wPawns >> 7;
    black_safe_squares ^= board.wPawns >> 9;

    var black_behind: u64 = 0;
    black_behind |= black_center & board.bPawns >> 8;
    black_behind |= black_center & board.bPawns >> 16;
    black_behind |= black_center & board.bPawns >> 24;

    return @intCast(bit.bitCount(black_safe_squares) + bit.bitCount(black_behind));
}
