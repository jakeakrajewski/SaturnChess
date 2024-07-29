const map = @import("Maps.zig");
const std = @import("std");
const sqr = @import("Square.zig");
const bit = @import("BitManipulation.zig");

pub const Castle = enum(u4) { N = 0, WK = 1, WQ = 2, BK = 4, BQ = 8 };
pub const Pieces = enum(u4) { P = 0, N = 1, B = 2, R = 3, Q = 4, K = 5, p = 6, n = 7, b = 8, r = 9, q = 10, k = 11 };
pub const piece_array: [12]Pieces = [12]Pieces{ .P, .N, .B, .R, .Q, .K, .p, .n, .b, .r, .q, .k };

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
    hashKey: u64 = 0,

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
            if ((map.pawn_attacks[0][square] & self.bPawns) > 0) attackers += 1;
        } else {
            if ((map.pawn_attacks[1][square] & self.wPawns) > 0) attackers += 1;
        }

        const knights = if (side == 0) self.bKnights else self.wKnights;
        const bishops = if (side == 0) self.bBishops else self.wBishops;
        const rooks = if (side == 0) self.bRooks else self.wRooks;
        const queens = if (side == 0) self.bQueens else self.wQueens;
        const king = if (side == 0) self.bKing else self.wKing;

        if ((map.getBishopAttacks(square, self.allPieces()) & bishops) > 0) attackers += 1;
        if ((map.getRookAttacks(square, self.allPieces()) & rooks) > 0) attackers += 1;
        if ((map.generateQueenAttacks(square, self.allPieces()) & queens) > 0) attackers += 1;
        if ((map.knight_attacks[square] & knights) > 0) attackers += 1;
        if ((map.king_attacks[square] & king) > 0) attackers += 1;
        return attackers;
    }

    pub inline fn isEmptySquare(self: *Board, square: u6) bool {
        return @as(u64, square) & ~(self.wPieces | self.bPieces) > 0;
    }

    pub inline fn getPieceAttacks(self: *Board, piece: Pieces, source: u6, side: u1) u64 {
        const occupancy = if (side == 0) self.wPieces() else self.bPieces();
        switch (piece) {
            .P, .p => {
                return map.pawn_attacks[side][source];
            },
            .N, .n => {
                return map.knight_attacks[source] & ~occupancy;
            },
            .B, .b => {
                return map.getBishopAttacks(source, self.allPieces()) & ~occupancy;
            },
            .R, .r => {
                return map.getRookAttacks(source, self.allPieces()) & ~occupancy;
            },
            .Q, .q => {
                const rook_targets = map.getRookAttacks(source, self.allPieces()) & ~occupancy;
                const bishop_targets = map.getBishopAttacks(source, self.allPieces()) & ~occupancy;
                return rook_targets | bishop_targets;
            },
            .K, .k => {
                return map.king_attacks[source] & ~occupancy;
            },
        }
    }

    pub inline fn getPieceBitBoard(self: *Board, piece: Pieces) *u64 {
        switch (piece) {
            .P => {
                return &self.wPawns;
            },
            .N => {
                return &self.wKnights;
            },
            .B => {
                return &self.wBishops;
            },
            .R => {
                return &self.wRooks;
            },
            .Q => {
                return &self.wQueens;
            },
            .K => {
                return &self.wKing;
            },
            .p => {
                return &self.bPawns;
            },
            .n => {
                return &self.bKnights;
            },
            .b => {
                return &self.bBishops;
            },
            .r => {
                return &self.bRooks;
            },
            .q => {
                return &self.bQueens;
            },
            .k => {
                return &self.bKing;
            },
        }
    }

    pub inline fn updateBoard(self: *Board, piece: Pieces, source: u6, target: u6, side: u1, isEP: bool) void {
        switch (piece) {
            .P => {
                bit.popBit(&self.wPawns, source);
                bit.setBit(&self.wPawns, target);
                if (isEP) {
                    const ep_square: u6 = @truncate(bit.leastSignificantBit(self.enPassantSquare));
                    bit.popBit(&self.bPawns, ep_square + 8);
                }
            },
            Pieces.N => {
                bit.popBit(&self.wKnights, source);
                bit.setBit(&self.wKnights, target);
            },
            Pieces.B => {
                bit.popBit(&self.wBishops, source);
                bit.setBit(&self.wBishops, target);
            },
            Pieces.R => {
                bit.popBit(&self.wRooks, source);
                bit.setBit(&self.wRooks, target);
            },
            Pieces.Q => {
                bit.popBit(&self.wQueens, source);
                bit.setBit(&self.wQueens, target);
            },
            Pieces.K => {
                bit.popBit(&self.wKing, source);
                bit.setBit(&self.wKing, target);
            },
            Pieces.p => {
                bit.popBit(&self.bPawns, source);
                bit.setBit(&self.bPawns, target);
                if (isEP) {
                    const epSquare: u6 = @truncate(bit.leastSignificantBit(self.enPassantSquare));
                    bit.popBit(&self.wPawns, epSquare - 8);
                }
            },
            Pieces.n => {
                bit.popBit(&self.bKnights, source);
                bit.setBit(&self.bKnights, target);
            },
            Pieces.b => {
                bit.popBit(&self.bBishops, source);
                bit.setBit(&self.bBishops, target);
            },
            Pieces.r => {
                bit.popBit(&self.bRooks, source);
                bit.setBit(&self.bRooks, target);
            },
            Pieces.q => {
                bit.popBit(&self.bQueens, source);
                bit.setBit(&self.bQueens, target);
            },
            Pieces.k => {
                bit.popBit(&self.bKing, source);
                bit.setBit(&self.bKing, target);
            },
        }

        if (side == 0) {
            bit.popBit(&self.bPawns, target);
            bit.popBit(&self.bKnights, target);
            bit.popBit(&self.bBishops, target);
            bit.popBit(&self.bRooks, target);
            bit.popBit(&self.bQueens, target);
        } else {
            bit.popBit(&self.wPawns, target);
            bit.popBit(&self.wKnights, target);
            bit.popBit(&self.wBishops, target);
            bit.popBit(&self.wRooks, target);
            bit.popBit(&self.wQueens, target);
        }
    }

    pub fn generateBoardArray(self: *Board) [12]u64 {
        return [12]u64{ self.wPawns, self.wKnights, self.wBishops, self.wRooks, self.wQueens, self.wKing, self.bPawns, self.bKnights, self.bBishops, self.bRooks, self.bQueens, self.bKing };
    }

    pub fn GetPieceAtSquare(self: *Board, square: u6) ?Pieces {
        const square_board = @as(u64, 1) << square;
        if (self.allPieces() & square_board > 0) {
            if ((self.wPawns | self.bPawns) & square_board > 0) return .P;
            if ((self.wKnights | self.bKnights) & square_board > 0) return .N;
            if ((self.wBishops | self.bBishops) & square_board > 0) return .B;
            if ((self.wRooks | self.bRooks) & square_board > 0) return .R;
            if ((self.wQueens | self.bQueens) & square_board > 0) return .Q;
            if ((self.wKing | self.bKing) & square_board > 0) return .K;
            return null;
        } else {
            return null;
        }
    }
};

pub fn EmptyBoard() Board {
    return Board{ .wPawns = 0, .wKnights = 0, .wBishops = 0, .wRooks = 0, .wQueens = 0, .wKing = 0, .bPawns = 0, .bKnights = 0, .bBishops = 0, .bRooks = 0, .bQueens = 0, .bKing = 0, .enPassantSquare = undefined, .sideToMove = 0, .castle = 0 };
}

pub fn setBoardFromFEN(fen: []const u8, board: *Board) void {
    board.* = EmptyBoard();

    var fen_parts = std.mem.split(u8, fen, " ");
    const piece_placement = fen_parts.next().?;
    const side_to_move_str = fen_parts.next().?;
    const castling_availability = fen_parts.next().?;
    const en_passant_square_str = fen_parts.next().?;

    var rank: u64 = 0;
    var file: u64 = 0;

    for (piece_placement) |c| {
        switch (c) {
            '1'...'8' => file += @intCast(c - '0'),
            '/' => {
                rank += 1;
                file = 0;
            },
            else => {
                const piece = PieceFromString(c);
                const bit_pos: u64 = (rank * 8) + file;
                const bit_mask: u64 = @as(u64, 1) << @intCast(bit_pos);

                switch (piece) {
                    Pieces.P => {
                        board.wPawns |= bit_mask;
                    },
                    Pieces.N => {
                        board.wKnights |= bit_mask;
                    },
                    Pieces.B => {
                        board.wBishops |= bit_mask;
                    },
                    Pieces.R => {
                        board.wRooks |= bit_mask;
                    },
                    Pieces.Q => {
                        board.wQueens |= bit_mask;
                    },
                    Pieces.K => {
                        board.wKing |= bit_mask;
                    },
                    Pieces.p => {
                        board.bPawns |= bit_mask;
                    },
                    Pieces.n => {
                        board.bKnights |= bit_mask;
                    },
                    Pieces.b => {
                        board.bBishops |= bit_mask;
                    },
                    Pieces.r => {
                        board.bRooks |= bit_mask;
                    },
                    Pieces.q => {
                        board.bQueens |= bit_mask;
                    },
                    Pieces.k => {
                        board.bKing |= bit_mask;
                    },
                }
                file += 1;
            },
        }
    }

    board.sideToMove = if (side_to_move_str[0] == 'w') 0 else 1;

    for (castling_availability) |c| {
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

    if (en_passant_square_str[0] != '-') {
        const file_char = en_passant_square_str[0];
        const rank_char = en_passant_square_str[1];
        const f = file_char - 'a';
        const r = '8' - rank_char;
        const bit_pos: u64 = (r * 8) + f;
        board.enPassantSquare = @as(u64, 1) << @intCast(bit_pos);
    } else {
        board.enPassantSquare = 0;
    }
}
