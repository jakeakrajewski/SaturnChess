const map = @import("Maps.zig");
const std = @import("std");
const sqr = @import("Square.zig");
const bit = @import("BitManipulation.zig");

pub const Castle = enum(u4) { N = 0, WK = 1, WQ = 2, BK = 4, BQ = 8 };
pub const Pieces = enum(u4) { P = 0, N = 1, B = 2, R = 3, Q = 4, K = 5, p = 6, n = 7, b = 8, r = 9, q = 10, k = 11 };

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

pub const Board = struct {
    wPawns: u64,
    wKnights: u64,
    wBishops: u64,
    wRooks: u64,
    wQueens: u64,
    wKing: u64,
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

    pub fn bPieces(self: *Board) u64 {
        return self.bPawns | self.bKnights | self.bBishops | self.bRooks | self.bQueens | self.bKing;
    }
    pub fn wPieces(self: *Board) u64 {
        return self.wPawns | self.wKnights | self.wBishops | self.wRooks | self.wQueens | self.wKing;
    }
    pub fn allPieces(self: *Board) u64 {
        return self.wPieces() | self.bPieces();
    }

    pub inline fn isSquareAttacked(self: *Board, square: u6, side: u1) u6 {
        var attackers: u6 = 0;
        if (side == 0) {
            if ((map.pawnAttacks[0][square] & self.bPawns) > 0) attackers += 1;
        } else {
            if ((map.pawnAttacks[1][square] & self.wPawns) > 0) attackers += 1;
        }

        const knights = if (side == 0) self.bKnights else self.wKnights;
        const bishops = if (side == 0) self.bBishops else self.wBishops;
        const rooks = if (side == 0) self.bRooks else self.wRooks;
        const queens = if (side == 0) self.bQueens else self.wQueens;
        const king = if (side == 0) self.bKing else self.wKing;

        if ((map.GetBishopAttacks(square, self.allPieces()) & bishops) > 0) attackers += 1;
        if ((map.GetRookAttacks(square, self.allPieces()) & rooks) > 0) attackers += 1;
        if ((map.GenerateQueenAttacks(square, self.allPieces()) & queens) > 0) attackers += 1;
        if ((map.knightAttacks[square] & knights) > 0) attackers += 1;
        if ((map.kingAttacks[square] & king) > 0) attackers += 1;
        return attackers;
    }

    pub inline fn isEmptySquare(self: *Board, square: u6) bool {
        return @as(u64, square) & ~(self.wPieces | self.bPieces) > 0;
    }

    pub inline fn GetPieceAttacks(self: *Board, piece: Pieces, source: u6, side: u1) u64 {
        const occupancy = if (side == 0) self.wPieces() else self.bPieces();
        switch (piece) {
            .P, .p => {
                return map.pawnAttacks[side][source];
            },
            .N, .n => {
                return map.knightAttacks[source] & ~occupancy;
            },
            .B, .b => {
                return map.GetBishopAttacks(source, self.allPieces()) & ~occupancy;
            },
            .R, .r => {
                return map.GetRookAttacks(source, self.allPieces()) & ~occupancy;
            },
            .Q, .q => {
                const rookTargets = map.GetRookAttacks(source, self.allPieces()) & ~occupancy;
                const bishopTargets = map.GetBishopAttacks(source, self.allPieces()) & ~occupancy;
                return rookTargets | bishopTargets;
            },
            .K, .k => {
                return map.kingAttacks[source] & ~occupancy;
            },
        }
    }

    pub inline fn GetPieceBitBoard(self: *Board, piece: Pieces) *u64 {
        switch (piece) {
            Pieces.P => {
                return &self.wPawns;
            },
            Pieces.N => {
                return &self.wKnights;
            },
            Pieces.B => {
                return &self.wBishops;
            },
            Pieces.R => {
                return &self.wRooks;
            },
            Pieces.Q => {
                return &self.wQueens;
            },
            Pieces.K => {
                return &self.wKing;
            },
            Pieces.p => {
                return &self.bPawns;
            },
            Pieces.n => {
                return &self.bKnights;
            },
            Pieces.b => {
                return &self.bBishops;
            },
            Pieces.r => {
                return &self.bRooks;
            },
            Pieces.q => {
                return &self.bQueens;
            },
            Pieces.k => {
                return &self.bKing;
            },
        }
    }

    pub inline fn UpdateBoard(self: *Board, piece: Pieces, source: u6, target: u6, side: u1, isEP: bool) void {
        switch (piece) {
            Pieces.P => {
                bit.PopBit(&self.wPawns, source);
                bit.SetBit(&self.wPawns, target);
                if (isEP) {
                    const epSquare: u6 = @truncate(bit.LeastSignificantBit(self.enPassantSquare));
                    bit.PopBit(&self.bPawns, epSquare + 8);
                }
            },
            Pieces.N => {
                bit.PopBit(&self.wKnights, source);
                bit.SetBit(&self.wKnights, target);
            },
            Pieces.B => {
                bit.PopBit(&self.wBishops, source);
                bit.SetBit(&self.wBishops, target);
            },
            Pieces.R => {
                bit.PopBit(&self.wRooks, source);
                bit.SetBit(&self.wRooks, target);
            },
            Pieces.Q => {
                bit.PopBit(&self.wQueens, source);
                bit.SetBit(&self.wQueens, target);
            },
            Pieces.K => {
                bit.PopBit(&self.wKing, source);
                bit.SetBit(&self.wKing, target);
            },
            Pieces.p => {
                bit.PopBit(&self.bPawns, source);
                bit.SetBit(&self.bPawns, target);
                if (isEP) {
                    const epSquare: u6 = @truncate(bit.LeastSignificantBit(self.enPassantSquare));
                    bit.PopBit(&self.wPawns, epSquare - 8);
                }
            },
            Pieces.n => {
                bit.PopBit(&self.bKnights, source);
                bit.SetBit(&self.bKnights, target);
            },
            Pieces.b => {
                bit.PopBit(&self.bBishops, source);
                bit.SetBit(&self.bBishops, target);
            },
            Pieces.r => {
                bit.PopBit(&self.bRooks, source);
                bit.SetBit(&self.bRooks, target);
            },
            Pieces.q => {
                bit.PopBit(&self.bQueens, source);
                bit.SetBit(&self.bQueens, target);
            },
            Pieces.k => {
                bit.PopBit(&self.bKing, source);
                bit.SetBit(&self.bKing, target);
            },
        }

        if (side == 0) {
            bit.PopBit(&self.bPawns, target);
            bit.PopBit(&self.bKnights, target);
            bit.PopBit(&self.bBishops, target);
            bit.PopBit(&self.bRooks, target);
            bit.PopBit(&self.bQueens, target);
        } else {
            bit.PopBit(&self.wPawns, target);
            bit.PopBit(&self.wKnights, target);
            bit.PopBit(&self.wBishops, target);
            bit.PopBit(&self.wRooks, target);
            bit.PopBit(&self.wQueens, target);
        }
    }

    pub fn GenerateBoardArray(self: *Board) [12]u64 {
        return [12]u64{ self.wPawns, self.wKnights, self.wBishops, self.wRooks, self.wQueens, self.wKing, self.bPawns, self.bKnights, self.bBishops, self.bRooks, self.bQueens, self.bKing };
    }

    pub fn GetPieceAtSquare(self: *Board, square: u6) ?Pieces {
        const squareBoard = @as(u64, 1) << square;
        if (self.allPieces() & squareBoard > 0) {
            if ((self.wPawns | self.bPawns) & squareBoard > 0) return .P;
            if ((self.wKnights | self.bKnights) & squareBoard > 0) return .N;
            if ((self.wBishops | self.bBishops) & squareBoard > 0) return .B;
            if ((self.wRooks | self.bRooks) & squareBoard > 0) return .R;
            if ((self.wQueens | self.bQueens) & squareBoard > 0) return .Q;
            if ((self.wKing | self.bKing) & squareBoard > 0) return .K;
            return null;
        } else {
            return null;
        }
    }
};

pub fn emptyBoard() Board {
    return Board{ .wPawns = 0, .wKnights = 0, .wBishops = 0, .wRooks = 0, .wQueens = 0, .wKing = 0, .bPawns = 0, .bKnights = 0, .bBishops = 0, .bRooks = 0, .bQueens = 0, .bKing = 0, .enPassantSquare = undefined, .sideToMove = 0, .castle = 0 };
}

pub fn setBoardFromFEN(fen: []const u8, board: *Board) void {
    board.* = emptyBoard();

    var fenParts = std.mem.split(u8, fen, " ");
    const piecePlacement = fenParts.next().?;
    const sideToMoveStr = fenParts.next().?;
    const castlingAvailability = fenParts.next().?;
    const enPassantSquareStr = fenParts.next().?;

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
                    },
                    Pieces.N => {
                        board.wKnights |= bitMask;
                    },
                    Pieces.B => {
                        board.wBishops |= bitMask;
                    },
                    Pieces.R => {
                        board.wRooks |= bitMask;
                    },
                    Pieces.Q => {
                        board.wQueens |= bitMask;
                    },
                    Pieces.K => {
                        board.wKing |= bitMask;
                    },
                    Pieces.p => {
                        board.bPawns |= bitMask;
                    },
                    Pieces.n => {
                        board.bKnights |= bitMask;
                    },
                    Pieces.b => {
                        board.bBishops |= bitMask;
                    },
                    Pieces.r => {
                        board.bRooks |= bitMask;
                    },
                    Pieces.q => {
                        board.bQueens |= bitMask;
                    },
                    Pieces.k => {
                        board.bKing |= bitMask;
                    },
                }
                file += 1;
            },
        }
    }

    board.sideToMove = if (sideToMoveStr[0] == 'w') 0 else 1;

    for (castlingAvailability) |c| {
        switch (c) {
            'K' => board.castle |= @intFromEnum(Castle.WK),
            'Q' => board.castle |= @intFromEnum(Castle.WQ),
            'k' => board.castle |= @intFromEnum(Castle.BK),
            'q' => board.castle |= @intFromEnum(Castle.BQ),
            '-' => {},
            else => {
                @panic("Invalid castling character");
            },
        }
    }

    if (enPassantSquareStr[0] != '-') {
        const fileChar = enPassantSquareStr[0];
        const rankChar = enPassantSquareStr[1];
        const f = fileChar - 'a';
        const r = '8' - rankChar;
        const bitPos: u64 = (r * 8) + f;
        board.enPassantSquare = @as(u64, 1) << @intCast(bitPos);
    } else {
        board.enPassantSquare = 0;
    }
}
