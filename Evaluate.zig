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

pub inline fn evaluate(board: brd.Board) i64 {
    var score: i64 = 0;
    score += materialScore(board);
    score += pieceSquareScore(board);
    return if (board.sideToMove == 0) score else -score;
}

pub inline fn materialCount(board: brd.Board) i64 {
    var b = board;
    return bit.bitCount(b.allPieces() ^ (board.wPawns | board.bPawns)) - 2;
}

pub inline fn materialScore(board: brd.Board) i64 {
    var score: i64 = 0;

    score += 100 * (@as(i64, bit.bitCount(board.wPawns)) - bit.bitCount(board.bPawns));
    score += 300 * (@as(i64, bit.bitCount(board.wKnights)) - bit.bitCount(board.bKnights));
    score += 300 * (@as(i64, bit.bitCount(board.wBishops)) - bit.bitCount(board.bBishops));
    score += 500 * (@as(i64, bit.bitCount(board.wRooks)) - bit.bitCount(board.bRooks));
    score += 900 * (@as(i64, bit.bitCount(board.wQueens)) - bit.bitCount(board.bQueens));
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
                        score -= king_psv[square];
                    } else {
                        score += king_mid_game_psv[square];
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
                        score -= black_king_psv[square];
                    } else {
                        score -= black_king_mid_game_psv[square];
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
    30, 30, 30, 40, 40, 30, 30, 30,
    20, 20, 20, 30, 30, 30, 20, 20,
    10, 10, 10, 20, 20, 10, 10, 10,
     5,  5, 10, 20, 20,  5,  5,  5,
     0,  0,  0,  5,  5,  0,  0,  0,
     0,  0,  0, -10,-10,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};

const black_pawn_psv: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0, -10,-10,  0,  0,  0,
     0,  0,  0,   5,  5,  0,  0,  0,
     5,  5, 10,  20, 20,  5,  5,  5,
    10, 10, 10,  20, 20, 10, 10, 10,
    20, 20, 20,  30, 30, 20, 20, 20,
    30, 30, 30,  40, 40, 30, 30, 30,
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
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  5,  5,  5,  5,  0,  0,
     0,  5,  5, 10,