const Maps = @import("../Maps/Maps.zig");
const color = @import("./Color.zig");
const std = @import("std");
const sqr = @import("../Board/Square.zig");
const bit = @import("../BitManipulation/BitManipulation.zig");

pub const Color = enum { WHITE, BLACK };
pub const Castle = enum(u4) { WK = 1, WQ = 2, BK = 4, BQ = 8 };
pub const Pieces = enum(u4) { P = 0, N = 1, B = 2, R = 3, Q = 4, K = 5, p = 6, n = 7, b = 8, r = 9, q = 10, k = 11 };
pub const AsciiPieces: [12][]const u8 = .{ "P", "N", "B", "R", "Q", "K", "p", "n", "b", "r", "q", "k" };
pub const UnicodePieces: [12][]const u8 = .{ "♙", "♘", "♗", "♖", "♕", "♔", "♟︎", "♞", "♝", "♜", "♛", "♚" };

pub fn PieceFromString(piece: u8) Pieces {
    return switch (piece) {
        'P' => .P,
        'N' => .N,
        'B' => .B,
        'R' => .R,
        'Q' => .Q,
        'K' => .K,
        'p' => .p,
        'n' => .n,
        'b' => .b,
        'r' => .r,
        'q' => .q,
        'k' => .k,
        else => @panic("Invalid piece character"),
    };
}

pub var bitboards: [12]u64 = undefined;
pub var occupancies: [3]u64 = undefined;

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
    sideToMove: u1,
    enPassantSquare: u64,
    castle: u4,

    const emptySquares: u64 = ~(.wPieces | .bPieces);

    pub fn isSquareAttacked(self: *Board, square: u6, side: u1) bool {
        if (side == 0) {
            if ((Maps.pawnAttacks[1][square] & self.wPawns) > 0) return true;
        } else {
            if ((Maps.pawnAttacks[0][square] & self.bPawns) > 0) return true;
        }

        const knights = if (side == 0) self.bKnights else self.wKnights;
        const bishops = if (side == 0) self.bBishops else self.wBishops;
        const rooks = if (side == 0) self.bRooks else self.wRooks;
        const queens = if (side == 0) self.bQueens else self.wQueens;
        const king = if (side == 0) self.bKing else self.wKing;

        const allPieces = self.wPieces | self.bPieces;

        if ((Maps.GenerateBishopAttacks(square, allPieces) & bishops) > 0) return true;
        if ((Maps.GenerateRookAttacks(square, allPieces) & rooks) > 0) return true;
        if ((Maps.GenerateQueenAttacks(square, allPieces) & queens) > 0) return true;
        if ((Maps.knightAttacks[square] & knights) > 0) return true;
        if ((Maps.kingAttacks[square] & king) > 0) return true;
        return false;
    }

    pub fn isEmptySquare(self: *Board, square: u6) bool {
        return @as(u64, square) & ~(self.wPieces | self.bPieces) > 0;
    }
};

pub fn emptyBoard() Board {
    return Board{ .wPieces = 0, .wPawns = 0, .wKnights = 0, .wBishops = 0, .wRooks = 0, .wQueens = 0, .wKing = 0, .bPieces = 0, .bPawns = 0, .bKnights = 0, .bBishops = 0, .bRooks = 0, .bQueens = 0, .bKing = 0, .enPassantSquare = undefined, .sideToMove = 0, .castle = 0 };
}

pub fn setBoardFromFEN(fen: []const u8, board: *Board) void {
    // Clear all bitboards
    board.* = emptyBoard();

    var fenParts = std.mem.split(u8, fen, " ");
    const piecePlacement = fenParts.next().?;
    const sideToMoveStr = fenParts.next().?;
    const castlingAvailability = fenParts.next().?;
    const enPassantSquareStr = fenParts.next().?;

    // Parse piece placement
    var rank: u64 = 0;
    var file: u64 = 0;

    for (piecePlacement) |c| {
        switch (c) {
            '1'...'8' => file += @intCast(c - '0'),
            '/' => {
                rank += 1;
                file = 0;
            },
            else => {
                const piece = PieceFromString(c);
                const bitPos: u64 = (rank * 8) + file;
                const bitMask: u64 = @as(u64, 1) << @intCast(bitPos);

                switch (piece) {
                    Pieces.P => {
                        board.wPawns |= bitMask;
                        board.wPieces |= bitMask;
                    },
                    Pieces.N => {
                        board.wKnights |= bitMask;
                        board.wPieces |= bitMask;
                    },
                    Pieces.B => {
                        board.wBishops |= bitMask;
                        board.wPieces |= bitMask;
                    },
                    Pieces.R => {
                        board.wRooks |= bitMask;
                        board.wPieces |= bitMask;
                    },
                    Pieces.Q => {
                        board.wQueens |= bitMask;
                        board.wPieces |= bitMask;
                    },
                    Pieces.K => {
                        board.wKing |= bitMask;
                        board.wPieces |= bitMask;
                    },
                    Pieces.p => {
                        board.bPawns |= bitMask;
                        board.bPieces |= bitMask;
                    },
                    Pieces.n => {
                        board.bKnights |= bitMask;
                        board.bPieces |= bitMask;
                    },
                    Pieces.b => {
                        board.bBishops |= bitMask;
                        board.bPieces |= bitMask;
                    },
                    Pieces.r => {
                        board.bRooks |= bitMask;
                        board.bPieces |= bitMask;
                    },
                    Pieces.q => {
                        board.bQueens |= bitMask;
                        board.bPieces |= bitMask;
                    },
                    Pieces.k => {
                        board.bKing |= bitMask;
                        board.bPieces |= bitMask;
                    },
                }
                file += 1;
            },
        }
    }

    // Parse side to move
    board.sideToMove = if (sideToMoveStr[0] == 'w') 0 else 1;

    // Parse castling availability
    for (castlingAvailability) |c| {
        switch (c) {
            'K' => board.castle |= @intFromEnum(Castle.WK),
            'Q' => board.castle |= @intFromEnum(Castle.WQ),
            'k' => board.castle |= @intFromEnum(Castle.BK),
            'q' => board.castle |= @intFromEnum(Castle.BQ),
            '-' => {},
            else => @panic("Invalid castling character"),
        }
    }

    // Parse en passant square
    if (enPassantSquareStr[0] != '-') {
        const fileChar = enPassantSquareStr[0];
        const rankChar = enPassantSquareStr[1];
        const f = fileChar - 'a';
        const r = rankChar - '1';
        const bitPos: u64 = (r * 8) + f;
        board.enPassantSquare = @as(u64, 1) << @intCast(bitPos);
    } else {
        board.enPassantSquare = 0;
    }
}
