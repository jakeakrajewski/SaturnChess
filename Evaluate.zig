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
const phase: f32 = 0.0;
var end_game: bool = false;
pub var board: brd.Board = undefined;

pub inline fn evaluate(b: brd.Board) i64 {
    board = b;
    end_game = isEndGame(b);
    var score: i64 = 0;
    // phase = gamePhase(board);
    score += scorePawns(0) - scorePawns(1);
    score += materialScore();
    score += pawnSquareScore();
    score += scorePieces();
    return if (board.sideToMove == 0) score else -score;
}

pub inline fn materialCount() i64 {
    return bit.bitCount(board.allPieces() ^ (board.wPawns | board.bPawns)) - 2;
}
pub inline fn nonPawnMaterialValue() i64 {
    var score: i64 = 0;

    score += 100 * (@as(i64, bit.bitCount(board.wKnights)) + bit.bitCount(board.bKnights));
    score += 700 * (@as(i64, bit.bitCount(board.wBishops)) + bit.bitCount(board.bBishops));
    score += 800 * (@as(i64, bit.bitCount(board.wRooks)) + bit.bitCount(board.bRooks));
    score += 2500 * (@as(i64, bit.bitCount(board.wQueens)) + bit.bitCount(board.bQueens));

    return score;
}

pub inline fn isEndGame(b: brd.Board) bool {
    board = b;
    if (materialCount() <= 7) return true else return false;
}

// pub inline fn gamePhase() f32 {
//     const material = materialCount(board);
//     const max_material = 20800;
//     const end_game_cutoff = 10000;
//
//     if (material < end_game_cutoff) return 1;
//
//     return 1 - (material - end_game_cutoff) / (max_material - end_game_cutoff);
// }

pub inline fn materialScore() i64 {
    var score: i64 = 0;

    score += 100 * (@as(i64, bit.bitCount(board.wPawns)) - bit.bitCount(board.bPawns));
    score += 300 * (@as(i64, bit.bitCount(board.wKnights)) - bit.bitCount(board.bKnights));
    score += 300 * (@as(i64, bit.bitCount(board.wBishops)) - bit.bitCount(board.bBishops));
    score += 500 * (@as(i64, bit.bitCount(board.wRooks)) - bit.bitCount(board.bRooks));
    score += 1000 * (@as(i64, bit.bitCount(board.wQueens)) - bit.bitCount(board.bQueens));
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
        var passed_mask = map.getSquareFile(square);
        if (square % 8 > 0) passed_mask |= map.getSquareFile(square - 1);
        if (square % 8 < 7) passed_mask |= map.getSquareFile(square + 1);
        const board_ahead = ~@as(u64, 0) >> 63 - square;
        if (board.bPawns & passed_mask & board_ahead == 0) {
            score += passed_pawn_score[rank];
        }
        score += pawn_psv[square];
    }
    while (black_pawns > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(black_pawns));
        bit.popBit(&black_pawns, (@intCast(square)));
        const rank = 7 - square / 8;
        var passed_mask = map.getSquareFile(square);
        if (square % 8 > 0) passed_mask |= map.getSquareFile(square - 1);
        if (square % 8 < 7) passed_mask |= map.getSquareFile(square + 1);
        const board_ahead = ~@as(u64, 0) << square;
        if (board.wPawns & passed_mask & board_ahead == 0) {
            score -= passed_pawn_score[7 - rank];
        }
        score -= black_pawn_psv[square];
    }

    return score;
}

// zig fmt: off

const pawn_psv: [64]i64 = .{
    90, 90, 90, 90, 90, 90, 90, 90,
    40, 40, 40, 50, 50, 40, 40, 40,
    30, 30, 30, 40, 40, 40, 30, 30,
    10, 10, 10, 35, 35, 10, 10, 10,
     5,  5, 10, 35, 35,  5,  5,  5,
     0,  0,  0,  5,  5,  0,  0,  0,
     0,  0,  0, -10,-10,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};

const black_pawn_psv: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0, -10,-10,  0,  0,  0,
     0,  0,  0,   5,  5,  0,  0,  0,
     5,  5, 10,  35, 35,  5,  5,  5,
    10, 10, 10,  35, 35, 10, 10, 10,
    30, 30, 30,  40, 40, 30, 30, 30,
    40, 40, 40,  50, 50, 40, 40,430,
    90, 90, 90,  90, 90, 90, 90, 90,
};


const knight_psv: [64]i64 = .{
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0, 10, 10,  0,  0, -5,
    -5,  5, 20, 20, 20, 20,  5, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5,  5, 20, 10, 10, 20,  5, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,-10,  0,  0,  0,  0,-10, -5,
};

const black_knight_psv: [64]i64 = .{
    -5,-10,  0,  0,  0,  0,-10, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  5, 20, 10, 10, 20,  5, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5,  5, 20, 20, 20, 20,  5, -5,
    -5,  0,  0, 10, 10,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
};


const bishop_psv: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0, 10, 10,  0,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0, 10, 20, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0,  0,  0,  0,  0, 10,  0,
     0, 30,  0,  0,  0,  0, 30,  0,
};

const black_bishop_psv: [64]i64 = .{
     0, 30,  0,  0,  0,  0, 30,  0,
     0,  0,  0,  0,  0,  0, 10,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0, 10, 20, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0,  0, 10, 10,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};



const rook_psv: [64]i64 = .{
    50, 50, 50, 50, 50, 50, 50, 50,
    50, 50, 50, 50, 50, 50, 50, 50,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0,  0, 20, 20,  0,  0,  0,
};

const black_rook_psv: [64]i64 = .{
     0,  0,  0, 20, 20,  0,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    50, 50, 50, 50, 50, 50, 50, 50,
};

const king_psv: [64]i64 = .{
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
   20,  20,   0,   0,   0,   0,  20,  20,
   20,  30,  10,   0,   0,  10,  30,  20
};

const king_end_game_psv: [64]i64 = .{
    -50,-40,-30,-20,-20,-30,-40,-50,
    -30,-20,-10,  0,  0,-10,-20,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-30,  0,  0,  0,  0,-30,-30,
    -50,-30,-30,-30,-30,-30,-30,-50
};

const black_king_psv: [64]i64 = .{
   20,  30,  10,   0,   0,  10,  30,  20,
   20,  20,   0,   0,   0,   0,  20,  20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30
};

const black_king_end_game_psv: [64]i64 = .{
    -50,-30,-30,-30,-30,-30,-30,-50,
    -30,-30,  0,  0,  0,  0,-30,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-20,-10,  0,  0,-10,-20,-30,
    -50,-40,-30,-20,-20,-30,-40,-50
};

// zig fmt: on

fn scorePawns(side: u1) i64 {
    var score: i64 = 0;
    const pawns = if (side == 0) board.wPawns else board.bPawns;
    const opponent_pawns = if (side == 0) board.bPawns else board.wPawns;
    score -= 10 * (bit.bitCount(getIsolatedPawns(pawns)));
    score -= 5 * (bit.bitCount(getBackwardPawns(pawns, opponent_pawns, side)));
    score -= 10 * (bit.bitCount(getDoubledPawns(pawns)));
    score += 2 * (bit.bitCount(getConnectedPawns(pawns)));
    // score += 10 * (bit.bitCount(getPassedPawns(pawns, opponent_pawns, board.sideToMove)));
    return score;
}

fn getIsolatedPawns(pawns: u64) u64 {
    const leftAdjacent = (pawns >> 1) & 0x7f7f7f7f7f7f7f7f;
    const rightAdjacent = (pawns << 1) & 0xfefefefefefefefe;
    const adjacentPawns = leftAdjacent | rightAdjacent;

    return pawns & ~adjacentPawns;
}

fn getDoubledPawns(pawns: u64) u64 {
    const shiftedPawns = pawns << 8;
    const doubledPawns = pawns & shiftedPawns;
    return doubledPawns;
}

fn getConnectedPawns(pawns: u64) u64 {
    const leftAdjacent = (pawns >> 1) & 0x7f7f7f7f7f7f7f7f;
    const rightAdjacent = (pawns << 1) & 0xfefefefefefefefe;
    const connectedPawns = pawns & (leftAdjacent | rightAdjacent);
    return connectedPawns;
}

fn getBackwardPawns(ownPawns: u64, enemyPawns: u64, side: u1) u64 {
    const notAFile: u64 = 0xfefefefefefefefe;
    const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
    const isWhite: bool = side == 0;

    if (isWhite) {
        // Shift enemy pawns up to check for attack coverage in front of the pawns
        const enemyAttacks = (enemyPawns >> 7 & notAFile) | (enemyPawns >> 8) | (enemyPawns >> 9 & notHFile);
        // Shift own pawns to check for support coverage
        const ownLeft = (ownPawns >> 1) & notAFile;
        const ownRight = (ownPawns << 1) & notHFile;
        const unsupportedPawns = ownPawns & ~ownLeft & ~ownRight;
        const backwardPawns = unsupportedPawns & enemyAttacks;
        return backwardPawns;
    } else {
        // Shift enemy pawns down to check for attack coverage in front of the pawns
        const enemyAttacks = (enemyPawns << 7 & notHFile) | (enemyPawns << 8) | (enemyPawns << 9 & notAFile);
        // Shift own pawns to check for support coverage
        const ownLeft = (ownPawns >> 1) & notAFile;
        const ownRight = (ownPawns << 1) & notHFile;
        const unsupportedPawns = ownPawns & ~ownLeft & ~ownRight;
        const backwardPawns = unsupportedPawns & enemyAttacks;
        return backwardPawns;
    }
}

fn getPassedPawns(ownPawns: u64, enemyPawns: u64, side: u1) u64 {
    const notAFile: u64 = 0xfefefefefefefefe;
    const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
    const isWhite: bool = side == 0;

    // For white pawns, they advance up the board (shift left)
    if (isWhite) {
        const enemyPawnsInFront = (enemyPawns | (enemyPawns << 1 & notAFile) | (enemyPawns >> 1 & notHFile)) << 8;
        const enemyPawnsFurtherInFront = (enemyPawnsInFront | (enemyPawnsInFront << 8) | (enemyPawnsInFront << 16) | (enemyPawnsInFront << 24) | (enemyPawnsInFront << 32) | (enemyPawnsInFront << 40));
        return ownPawns & ~enemyPawnsFurtherInFront;
    } else {
        // For black pawns, they advance down the board (shift right)
        const enemyPawnsInFront = (enemyPawns | (enemyPawns << 1 & notAFile) | (enemyPawns >> 1 & notHFile)) >> 8;
        const enemyPawnsFurtherInFront = (enemyPawnsInFront | (enemyPawnsInFront >> 8) | (enemyPawnsInFront >> 16) | (enemyPawnsInFront >> 24) | (enemyPawnsInFront >> 32) | (enemyPawnsInFront >> 40));
        return ownPawns & ~enemyPawnsFurtherInFront;
    }
}

fn scorePieces() i64 {
    var score: i64 = 0;
    var b = board;

    while (b.wKnights > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wKnights));
        bit.popBit(&b.wKnights, (@intCast(square)));
        score += knight_psv[square];
    }
    while (b.wBishops > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wBishops));
        score += bishop_psv[square];
        bit.popBit(&b.wBishops, (@intCast(square)));
        score += 1 * (bit.bitCount(map.getBishopAttacks(square, board.allPieces())));
    }
    while (b.wRooks > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wRooks));
        const file = map.getSquareFile(square);
        score += rook_psv[square];
        score += if (file & board.wPawns & board.bPawns == 0) 15 else if (file & board.wPawns == 0) 10 else 0;
        bit.popBit(&b.wRooks, (@intCast(square)));
        score += 1 * (bit.bitCount(map.getRookAttacks(square, board.allPieces())));
    }
    while (b.wQueens > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.wQueens));
        bit.popBit(&b.wQueens, (@intCast(square)));
        score += 1 * (bit.bitCount(map.generateQueenAttacks(square, board.allPieces())));
    }
    while (b.bKnights > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bKnights));
        bit.popBit(&b.bKnights, (@intCast(square)));
        score -= black_knight_psv[square];
    }
    while (b.bBishops > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bBishops));
        score -= black_bishop_psv[square];
        bit.popBit(&b.bBishops, (@intCast(square)));
        score -= 1 * (bit.bitCount(map.getBishopAttacks(square, board.allPieces())));
    }
    while (b.bRooks > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bRooks));
        score -= black_rook_psv[square];
        const file = map.getSquareFile(square);
        score -= if (file & board.wPawns & board.bPawns == 0) 15 else if (file & board.bPawns == 0) 10 else 0;
        bit.popBit(&b.bRooks, (@intCast(square)));
        score -= 1 * (bit.bitCount(map.getRookAttacks(square, board.allPieces())));
    }
    while (b.bQueens > 0) {
        const square: u6 = @intCast(bit.leastSignificantBit(b.bQueens));
        bit.popBit(&b.bQueens, (@intCast(square)));
        score -= 1 * (bit.bitCount(map.generateQueenAttacks(square, board.allPieces())));
    }

    const white_king_square: u6 = @intCast(bit.leastSignificantBit(board.wKing));
    score += if (end_game) king_end_game_psv[white_king_square] else king_psv[white_king_square];
    const white_king_file = map.getSquareFile(white_king_square);
    score += 5 * bit.bitCount(map.king_attacks[white_king_square] & board.wPieces());
    score -= if (white_king_file & board.wPawns & board.bPawns == 0) 15 else if (white_king_file & board.wPawns == 0) 10 else 0;

    const black_king_square: u6 = @intCast(bit.leastSignificantBit(board.bKing));
    score -= if (end_game) black_king_end_game_psv[black_king_square] else black_king_psv[black_king_square];
    const black_king_file = map.getSquareFile(black_king_square);
    score -= 5 * bit.bitCount(map.king_attacks[black_king_square] & board.bPieces());
    score += if (black_king_file & board.wPawns & board.bPawns == 0) 15 else if (black_king_file & board.wPawns == 0) 10 else 0;

    return score;
}
