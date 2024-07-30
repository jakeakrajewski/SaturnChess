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

pub inline fn evaluate(board: brd.Board) i64 {
    var score: i64 = 0;
    // phase = gamePhase(board);
    score += scorePawns(board.wPawns) - scorePawns(board.bPawns);
    score += materialScore(board);
    score += pieceSquareScore(board);
    score += scorePieces(board);
    return if (board.sideToMove == 0) score else -score;
}

pub inline fn materialCount(board: brd.Board) i64 {
    var b = board;
    return bit.bitCount(b.allPieces() ^ (board.wPawns | board.bPawns)) - 2;
}
pub inline fn nonPawnMaterialValue(board: brd.Board) i64 {
    var score: i64 = 0;

    score += 100 * (@as(i64, bit.bitCount(board.wKnights)) + bit.bitCount(board.bKnights));
    score += 700 * (@as(i64, bit.bitCount(board.wBishops)) + bit.bitCount(board.bBishops));
    score += 800 * (@as(i64, bit.bitCount(board.wRooks)) + bit.bitCount(board.bRooks));
    score += 2500 * (@as(i64, bit.bitCount(board.wQueens)) + bit.bitCount(board.bQueens));

    return score;
}

pub inline fn isEndGame(board: brd.Board) bool {
    if (materialCount(board) <= 7) return true else return false;
}

// pub inline fn gamePhase(board: brd.Board) f32 {
//     const material = materialCount(board);
//     const max_material = 20800;
//     const end_game_cutoff = 10000;
//
//     if (material < end_game_cutoff) return 1;
//
//     return 1 - (material - end_game_cutoff) / (max_material - end_game_cutoff);
// }

pub inline fn materialScore(board: brd.Board) i64 {
    var score: i64 = 0;

    score += 100 * (@as(i64, bit.bitCount(board.wPawns)) - bit.bitCount(board.bPawns));
    score += 300 * (@as(i64, bit.bitCount(board.wKnights)) - bit.bitCount(board.bKnights));
    score += 300 * (@as(i64, bit.bitCount(board.wBishops)) - bit.bitCount(board.bBishops));
    score += 500 * (@as(i64, bit.bitCount(board.wRooks)) - bit.bitCount(board.bRooks));
    score += 1000 * (@as(i64, bit.bitCount(board.wQueens)) - bit.bitCount(board.bQueens));
    score += 10000 * (@as(i64, bit.bitCount(board.wKing)) - bit.bitCount(board.bKing));

    return score;
}

pub inline fn pieceSquareScore(board: brd.Board) i64 {
    var b = board;
    var score: i64 = 0;
    const end_game = if (materialCount(board) <= 7) true else false;

    const bitBoards = b.generateBoardArray();

    for (0..12) |i| {
        var piece_board = bitBoards[i];

        while (piece_board > 0) {
            const square = bit.leastSignificantBit(piece_board);

            bit.popBit(&piece_board, (@intCast(square)));

            switch (i) {
                0 => {
                    score += pawn_psv[square];
                },
                1 => {
                    score += knight_psv[square];
                },
                2 => {
                    score += bishop_psv[square];
                },
                3 => {
                    score += rook_psv[square];
                },
                4 => {
                    continue;
                },
                5 => {
                    if (end_game) {
                        score -= king_end_game_psv[square];
                    } else {
                        score += king_psv[square];
                    }
                },
                6 => {
                    score -= black_pawn_psv[square];
                },
                7 => {
                    score -= black_knight_psv[square];
                },
                8 => {
                    score -= black_bishop_psv[square];
                },
                9 => {
                    score -= black_rook_psv[square];
                },
                10 => {
                    continue;
                },
                11 => {
                    if (end_game) {
                        score -= black_king_end_game_psv[square];
                    } else {
                        score -= black_king_psv[square];
                    }
                },
                else => {
                    continue;
                },
            }
        }
    }

    return score;
}

// zig fmt: off

const pawn_psv: [64]i64 = .{
    90, 90, 90, 90, 90, 90, 90, 90,
    40, 40, 40, 50, 50, 40, 40, 40,
    30, 30, 30, 40, 40, 40, 30, 30,
    10, 10, 10, 35, 35, 10, 10, 10,
     5,  5, 10, 30, 30,  5,  5,  5,
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

fn scorePawns(pawns: u64) i64 {
    var score: i64 = 0;
    score -= 5 * (bit.bitCount(getIsolatedPawns(pawns)));
    score -= 10 * (bit.bitCount(getDoubledPawns(pawns)));
    score += 1 * (bit.bitCount(getConnectedPawns(pawns)));
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

fn scorePieces(board: brd.Board) i64{
    var score: i64 = 0;
    score += sliderMobility(board);
    score += kingSafety(board);

    return score;
}
 
fn sliderMobility(board: brd.Board) i64 {
    var score: i64 = 0;
    var b = board;
    var white_bishops = board.wBishops;
    var white_rooks = board.wRooks;
    var white_queens = board.wQueens;
    var black_bishops = board.bBishops;
    var black_rooks = board.bRooks;
    var black_queens = board.bQueens;
    
    while (white_bishops > 0) {
         const square: u6 = @intCast(bit.leastSignificantBit(white_bishops));
         bit.popBit(&white_bishops, (@intCast(square)));
         score += 2 * (bit.bitCount(map.getBishopAttacks(square, b.allPieces())));
    }
    while (white_rooks > 0) {
         const square: u6 = @intCast(bit.leastSignificantBit(white_rooks));
         bit.popBit(&white_rooks, (@intCast(square)));
         score += 2 * (bit.bitCount(map.getRookAttacks(square, b.allPieces())));
    }
    while (white_queens > 0) {
         const square: u6 = @intCast(bit.leastSignificantBit(white_queens));
         bit.popBit(&white_queens, (@intCast(square)));
         score += 2 * (bit.bitCount(map.generateQueenAttacks(square, b.allPieces())));
    }
    while (black_bishops > 0) {
         const square: u6 = @intCast(bit.leastSignificantBit(black_bishops));
         bit.popBit(&black_bishops, (@intCast(square)));
         score -= 2 * (bit.bitCount(map.getBishopAttacks(square, b.allPieces())));
    }
    while (black_rooks > 0) {
         const square: u6 = @intCast(bit.leastSignificantBit(black_rooks));
         bit.popBit(&black_rooks, (@intCast(square)));
         score -= 2 * (bit.bitCount(map.getRookAttacks(square, b.allPieces())));
    }
    while (black_queens > 0) {
         const square: u6 = @intCast(bit.leastSignificantBit(black_queens));
         bit.popBit(&black_queens, (@intCast(square)));
         score -= 2 * (bit.bitCount(map.generateQueenAttacks(square, b.allPieces())));
    }

    return score;
}

fn kingSafety(board: brd.Board) i64 {
    var b = board;
    const white_king: usize = @intCast(bit.leastSignificantBit(board.wKing));
    const black_king: usize = @intCast(bit.leastSignificantBit(board.bKing));
    const white_safety = bit.bitCount(map.king_attacks[white_king] & b.wPieces());
    const black_safety = bit.bitCount(map.king_attacks[black_king] & b.bPieces());
    return (@as(i16, white_safety) * 1) - (@as(i16, black_safety) * 1);
}
