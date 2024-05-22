const Maps = @import("../Maps/Maps.zig");
const color = @import("./Color.zig");

const WHITE = color.Color.WHITE;
const BLACK = color.Color.BLACK;

pub var Board = struct {
    wPieces: u64,
    wPawns: u64,
    wKnights: u64,
    wBishops: u64,
    wRooks: u64,
    wQueens: u64,
    wKing: u64,
    bPieces: u64,
    bPawns: u64,
    bKnights: u64,
    bBishops: u64,
    bRooks: u64,
    bQueens: u64,
    bKing: u64,

    enPassantSquare: u64,

    fn emptySquares(self: *Board) u64 {
        return ~(self.wPieces | self.bPieces);
    }

    fn singlePawnPush(self: *Board, clr: color.Color) u64 {
        if (clr == WHITE) {
            return (self.wPawns << 8) & emptySquares(self);
        } else {
            return (self.bPawns >> 8) & emptySquares(self);
        }
    }

    fn doublePawnPush(self: *Board, clr: color.Color) u64 {
        const diff: u8 = if (clr == WHITE) 8 else -8;
        const skippedSquares: u64 = singlePawnPush(self, clr) << diff;
        if (clr == color.Color.WHITE) {
            return (self.wPawns << 8) & skippedSquares & Maps.Rank_2;
        } else {
            return (self.bPawns >> 8) & skippedSquares & Maps.Rank_6;
        }
    }
};

fn newBoard() Board {
    return Board{ .wPieces = Maps.Rank_1 | Maps.Rank_2, .wPawns = Maps.Rank_2, .wKnights = 42, .wBishops = 36, .wRooks = 129, .wQueens = 16, .wKing = 8, .bPieces = Maps.Rank_8 | Maps.Rank_7, .bPawns = Maps.Rank_7, .bKnights = .wKnights << 56, .bBishops = .wBishops << 56, .bRooks = .wRooks << 56, .bQueens = .wQueens << 56, .bKing = .wKing << 56 };
}
