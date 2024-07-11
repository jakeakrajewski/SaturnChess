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

pub inline fn Evaluate(board: brd.Board) i64 {
    var score: i64 = 0;
    score += MaterialScore(board);
    score += PieceSquareScore(board);
    return score;
}
pub inline fn MaterialScore(board: brd.Board) i64 {
    var score: i64 = 0;

    score += 100 * @as(i64, bit.BitCount(board.wPawns)) - bit.BitCount(board.bPawns);
    score += 300 * @as(i64, bit.BitCount(board.wKnights)) - bit.BitCount(board.bKnights);
    score += 300 * @as(i64, bit.BitCount(board.wBishops)) - bit.BitCount(board.bBishops);
    score += 500 * @as(i64, bit.BitCount(board.wRooks)) - bit.BitCount(board.bRooks);
    score += 900 * @as(i64, bit.BitCount(board.wQueens)) - bit.BitCount(board.bQueens);
    score += 10000 * @as(i64, bit.BitCount(board.wKing)) - bit.BitCount(board.bKing);

    return if (board.sideToMove == 0) score else -score;
}

pub inline fn PieceSquareScore(board: brd.Board) i64 {
    var b = board;
    var score: i64 = 0;

    const bitBoards = b.GenerateBoardArray();

    for (0..12) |i| {
        var pieceBoard = bitBoards[i];

        while (pieceBoard > 0) {
            const square = bit.LeastSignificantBit(pieceBoard);

            bit.PopBit(&pieceBoard, try sqr.Square.fromIndex(@intCast(square)));

            switch (i) {
                0 => {
                    score += pawnPSV[square];
                },
                1 => {
                    score += knightPSV[square];
                },
                2 => {
                    score += bishopPSV[square];
                },
                3 => {
                    score += rookPSV[square];
                },
                4 => {
                    continue;
                },
                5 => {
                    score -= kingScorePSV[square];
                },
                6 => {
                    score -= blackPawnPSV[square];
                },
                7 => {
                    score -= blackKnightPSV[square];
                },
                8 => {
                    score -= blackBishopPSV[square];
                },
                9 => {
                    score -= blackRookPSV[square];
                },
                10 => {
                    continue;
                },
                11 => {
                    score -= blackKingScorePSV[square];
                },
                else => {
                    continue;
                },
            }
        }
    }

    return if (board.sideToMove == 0) score else -score;
}

// zig fmt: off

const pawnPSV: [64]i64 = .{
    90, 90, 90, 90, 90, 90, 90, 90,
    30, 30, 30, 40, 40, 30, 30, 30,
    20, 20, 20, 30, 30, 30, 20, 20,
    10, 10, 10, 20, 20, 10, 10, 10,
     5,  5, 10, 20, 20,  5,  5,  5,
     0,  0,  0,  5,  5,  0,  0,  0,
     0,  0,  0, -10,-10,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};

const blackPawnPSV: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0, -10,-10,  0,  0,  0,
     0,  0,  0,   5,  5,  0,  0,  0,
     5,  5, 10,  20, 20,  5,  5,  5,
    10, 10, 10,  20, 20, 10, 10, 10,
    20, 20, 20,  30, 30, 20, 20, 20,
    30, 30, 30,  40, 40, 30, 30, 30,
    90, 90, 90,  90, 90, 90, 90, 90,
};


const knightPSV: [64]i64 = .{
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0, 10, 10,  0,  0, -5,
    -5,  5, 20, 20, 20, 20,  5, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5,  5, 20, 10, 10, 20,  5, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,-10,  0,  0,  0,  0,-10, -5,
};

const blackKnightPSV: [64]i64 = .{
    -5,-10,  0,  0,  0,  0,-10, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  5, 20, 10, 10, 20,  5, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5, 10, 20, 30, 30, 20, 10, -5,
    -5,  5, 20, 20, 20, 20,  5, -5,
    -5,  0,  0, 10, 10,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
};


const bishopPSV: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0, 10, 10,  0,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0, 10, 20, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0,  0,  0,  0,  0, 10,  0,
     0, 30,  0,  0,  0,  0, 30,  0,
};

const blackBishopPSV: [64]i64 = .{
     0, 30,  0,  0,  0,  0, 30,  0,
     0,  0,  0,  0,  0,  0, 10,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0, 10, 20, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0,  0, 10, 10,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};



const rookPSV: [64]i64 = .{
    50, 50, 50, 50, 50, 50, 50, 50,
    50, 50, 50, 50, 50, 50, 50, 50,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0,  0, 20, 20,  0,  0,  0,
};

const blackRookPSV: [64]i64 = .{
     0,  0,  0, 20, 20,  0,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
     0,  0, 10, 20, 20, 10,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    50, 50, 50, 50, 50, 50, 50, 50,
};



const kingScorePSV: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  5,  5,  5,  5,  0,  0,
     0,  5,  5, 10, 10,  5,  5,  0,
     0,  5, 10, 20, 20, 10,  5,  0,
     0,  5, 10, 20, 20, 10,  5,  0,
     0,  5,  5, 10, 10,  5,  5,  0,
     0,  5,  5,  0,  0,  5,  5,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};

const blackKingScorePSV: [64]i64 = .{
     0,  0,  0,  0,  0,  0,  0,  0,
     0,  5,  5,  0,  0,  5,  5,  0,
     0,  5,  5, 10, 10,  5,  5,  0,
     0,  5, 10, 20, 20, 10,  5,  0,
     0,  5, 10, 20, 20, 10,  5,  0,
     0,  5,  5, 10, 10,  5,  5,  0,
     0,  0,  5,  5,  5,  5,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,
};

