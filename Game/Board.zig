const Maps = @import("../Maps/Maps.zig");
const color = @import("./Color.zig");

const WHITE = color.Color.WHITE;
const BLACK = color.Color.BLACK;

pub const Board = struct {
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
    const emptySquares: u64 = ~(.wPieces | .bPieces);

    // Pawn Moves
    const wPawnSinglePush = (.wPawns << 8) & emptySquares;
    const bPawnSinglePush = (.bPawns >> 8) & emptySquares;
    const wPawnDoublePush = (.wPawns << 16) & (wPawnSinglePush << 8) & Maps.RANK_2;
    const bPawnDoublePush = (.bPawns >> 16) & (bPawnSinglePush >> 8) & Maps.RANK_7;
    const wPawnCapturesRight = (.wPawns << 9) & .bPieces & ~Maps.FILE_H;
    const wPawnCapturesLeft = (.wPawns << 7) & .bPieces & ~Maps.FILE_A;
    const bPawnCapturesRight = (.bPawns >> 7) & .wPieces & ~Maps.FILE_A;
    const bPawnCapturesLeft = (.bPawns >> 9) & .wPieces & ~Maps.FILE_H;
    const wPawnEnPassantRight = (.wPawns << 9) & .enPassantSquare & ~Maps.FILE_H;
    const wPawnEnPassantLeft = (.wPawns << 7) & .enPassantSquare & ~Maps.FILE_A;
    const bPawnEnPassantRight = (.bPawns >> 7) & .enPassantSquare & ~Maps.FILE_A;
    const bPawnEnPassantLeft = (.bPawns >> 9) & .enPassantSquare & ~Maps.FILE_H;
    const wPromotion = wPawnSinglePush & Maps.Rank_8;
    const bPromotion = bPawnSinglePush & Maps.RANK_1;

    fn knightMoves(self: *Board, clr: color.Color) u64 {
        const knightAttacks = Maps.KNIGHT_MOVES;
        var knights: u64 = if (clr == color.Color.WHITE) self.wKnights else self.bKnights;
        var nMoves: u64 = 0;

        while (knights != 0) {
            const index = @ctz(knights);
            nMoves |= knightAttacks[index];
            knights &= knights - 1;
        }
        return nMoves;
    }

    const wKingMoves = Maps.KING_MOVES[@ctz(.wKing)];
    const bKingMoves = Maps.KING_MOVES[@ctz(.bKing)];
};

pub fn newBoard() Board {
    return Board{ .wPieces = Maps.Rank_1 | Maps.Rank_2, .wPawns = Maps.Rank_2, .wKnights = 42, .wBishops = 36, .wRooks = 129, .wQueens = 8, .wKing = 16, .bPieces = Maps.Rank_8 | Maps.Rank_7, .bPawns = Maps.Rank_7, .bKnights = .wKnights << 56, .bBishops = .wBishops << 56, .bRooks = .wRooks << 56, .bQueens = .wQueens << 56, .bKing = .wKing << 56 };
}
