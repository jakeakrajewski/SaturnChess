const std = @import("std");
const brd = @import("../Board/Board.zig");
const map = @import("../Maps/Maps.zig");
const bit = @import("../BitManipulation/BitManipulation.zig");
const sqr = @import("../Board/Square.zig");

pub fn GenerateMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    try PawnMoves(list, board, side);
    try KnightMoves(list, board, side);
    try BishopMoves(list, board, side);
    try RookMoves(list, board, side);
    try QueenMoves(list, board, side);
    try KingMoves(list, board, side);
    try CastleMoves(list, board, side);

    var moveList: std.ArrayList(Move) = try list.clone();
    moveList.clearRetainingCapacity();

    for (0..list.items.len) |i| {
        var boardCopy = board.*;
        const result = MakeMove(list.items[i], &boardCopy, side);

        if (result) {
            try moveList.append(list.items[i]);
        }
    }
    list.clearAndFree();
    try list.appendSlice(moveList.items);
}

pub fn PawnMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.P else brd.Pieces.p;
    var bitBoard: u64 = undefined;

    if (side == 0) {
        bitBoard = board.wPawns;

        while (bitBoard > 0) {
            const source: u6 = @intCast(bit.LeastSignificantBit(bitBoard));
            const epSquare: u6 = @truncate(bit.LeastSignificantBit(board.enPassantSquare));
            bit.PopBit(&bitBoard, try sqr.Square.fromIndex(source));
            if (source == 64) break;

            var target = source - 8;
            if (target < 0) continue;

            const rank: u4 = @intCast(8 - (source / 8));
            var pieceAtTarget: bool = (@as(u64, 1) << target) & board.allPieces() > 0;
            if (!pieceAtTarget) {
                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N });
                } else {
                    try list.append(Move{ .source = source, .target = target, .piece = piece });

                    pieceAtTarget = (@as(u64, 1) << target - 8) & board.allPieces() > 0;
                    if (rank == 2 and !pieceAtTarget) {
                        // Double pawn push
                        try list.append(Move{ .source = source, .target = target - 8, .piece = piece, .isDoublePush = true });
                    }
                }
            }

            var attackMap = try map.MaskPawnAttacks(source, 0);
            attackMap &= (board.bPieces() | board.enPassantSquare);
            while (attackMap > 0) {
                target = @intCast(bit.LeastSignificantBit(attackMap));

                bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N, .isCapture = true });
                } else {
                    if (target == epSquare) {
                        try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true, .isEnPassant = true });
                    } else {
                        try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
                    }
                }
            }
        }
    } else {
        bitBoard = board.bPawns;

        while (bitBoard > 0) {
            const source: u6 = @intCast(bit.LeastSignificantBit(bitBoard));
            const epSquare: u6 = @truncate(bit.LeastSignificantBit(board.enPassantSquare));
            bit.PopBit(&bitBoard, try sqr.Square.fromIndex(source));
            if (source == 64) break;

            var target = source + 8;
            if (target > 63) continue;

            const rank: u4 = @intCast(8 - (source / 8));
            var pieceAtTarget: bool = (@as(u64, 1) << target) & board.allPieces() > 0;
            if (!pieceAtTarget) {
                if (rank == 2) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N });
                } else {
                    try list.append(Move{ .source = source, .target = target, .piece = piece });

                    pieceAtTarget = (@as(u64, 1) << target + 8) & board.allPieces() > 0;
                    if (rank == 7 and !pieceAtTarget) {
                        // Double pawn push
                        try list.append(Move{ .source = source, .target = target + 8, .piece = piece, .isDoublePush = true });
                    }
                }
            }

            var attackMap = try map.MaskPawnAttacks(source, 1);
            attackMap &= board.wPieces() | board.enPassantSquare;

            while (attackMap > 0) {
                target = @intCast(bit.LeastSignificantBit(attackMap));

                bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

                if (rank == 2) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N, .isCapture = true });
                } else {
                    if (target == epSquare) {
                        try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true, .isEnPassant = true });
                    } else {
                        try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
                    }
                }
            }
        }
    }
}

pub fn KnightMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.N else brd.Pieces.n;
    var knights = if (side == 0) board.wKnights else board.bKnights;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    while (knights > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(knights));
        bit.PopBit(&knights, try sqr.Square.fromIndex(source));
        var targets = try map.MaskKnightAttacks(source) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn BishopMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.B else brd.Pieces.b;
    var bishops = if (side == 0) board.wBishops else board.bBishops;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    while (bishops > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(bishops));
        bit.PopBit(&bishops, try sqr.Square.fromIndex(source));
        var targets = map.GetBishopAttacks(source, board.allPieces()) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn RookMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.R else brd.Pieces.r;
    var rooks = if (side == 0) board.wRooks else board.bRooks;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    while (rooks > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(rooks));
        bit.PopBit(&rooks, try sqr.Square.fromIndex(source));
        var targets = map.GetRookAttacks(source, board.allPieces()) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn QueenMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.Q else brd.Pieces.q;
    var queens = if (side == 0) board.wQueens else board.bQueens;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    while (queens > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(queens));
        bit.PopBit(&queens, try sqr.Square.fromIndex(source));
        const rookTargets = map.GetRookAttacks(source, board.allPieces()) & ~pieces;
        const bishopTargets = map.GetBishopAttacks(source, board.allPieces()) & ~pieces;
        var targets = rookTargets | bishopTargets;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn KingMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.K else brd.Pieces.k;
    var king = if (side == 0) board.wKing else board.bKing;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const enemyPieces = if (side == 0) board.bPieces() else board.wPieces();
    while (king > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(king));
        bit.PopBit(&king, try sqr.Square.fromIndex(source));
        var targets = try map.MaskKingAttacks(source) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub fn CastleMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const piece = if (side == 0) brd.Pieces.K else brd.Pieces.k;
    const rooks = if (side == 0) board.wRooks else board.bRooks;
    const king = if (side == 0) board.wKing else board.bKing;
    const atHomeSquare: bool = (side == 1 and king == (1 << 4)) or (side == 0 and king == (1 << 60));
    if (!atHomeSquare) return;

    if (side == 0) {
        const kingSideRook: bool = (rooks & (map.FILE_H & map.RANK_1)) > 0;
        const queenSideRook: bool = (rooks & (map.FILE_A & map.RANK_1)) > 0;
        const b1 = sqr.Square.toIndex(.B1);
        const c1 = sqr.Square.toIndex(.C1);
        const d1 = sqr.Square.toIndex(.D1);
        const f1 = sqr.Square.toIndex(.F1);
        const g1 = sqr.Square.toIndex(.G1);
        const kingSideCastleEmpty = bit.GetBit(board.allPieces(), f1) == 0 and bit.GetBit(board.allPieces(), g1) == 0;
        const kingSideCastleAttacked = board.isSquareAttacked(f1, 0) or board.isSquareAttacked(g1, 0);
        const queenSideCastleEmpty = bit.GetBit(board.allPieces(), b1) == 0 and bit.GetBit(board.allPieces(), c1) == 0 and bit.GetBit(board.allPieces(), d1) == 0;
        const queenSideCastleAttacked = board.isSquareAttacked(b1, 0) or board.isSquareAttacked(c1, 0) or board.isSquareAttacked(d1, 0);

        if (kingSideRook and kingSideCastleEmpty and !kingSideCastleAttacked) {
            try list.append(Move{
                .source = 60,
                .target = 62,
                .piece = piece,
                .castle = .WK,
            });
        }
        if (queenSideRook and queenSideCastleEmpty and !queenSideCastleAttacked) {
            try list.append(Move{
                .source = 60,
                .target = 58,
                .piece = piece,
                .castle = .WQ,
            });
        }
    } else {
        const kingSideRook: bool = (rooks & (map.FILE_H & map.RANK_8)) > 0;
        const queenSideRook: bool = (rooks & (map.FILE_A & map.RANK_8)) > 0;
        const b8 = sqr.Square.toIndex(.B8);
        const c8 = sqr.Square.toIndex(.C8);
        const d8 = sqr.Square.toIndex(.D8);
        const f8 = sqr.Square.toIndex(.F8);
        const g8 = sqr.Square.toIndex(.G8);
        const kingSideCastleEmpty = bit.GetBit(board.allPieces(), f8) == 0 and bit.GetBit(board.allPieces(), g8) == 0;
        const kingSideCastleAttacked = board.isSquareAttacked(f8, 1) or board.isSquareAttacked(g8, 1);
        const queenSideCastleEmpty = bit.GetBit(board.allPieces(), b8) == 0 and bit.GetBit(board.allPieces(), c8) == 0 and bit.GetBit(board.allPieces(), d8) == 0;
        const queenSideCastleAttacked = board.isSquareAttacked(b8, 1) or board.isSquareAttacked(c8, 1) or board.isSquareAttacked(d8, 1);

        if (kingSideRook and kingSideCastleEmpty and !kingSideCastleAttacked) {
            try list.append(Move{ .source = 4, .target = 6, .piece = piece, .castle = .BK });
        }
        if (queenSideRook and queenSideCastleEmpty and !queenSideCastleAttacked) {
            try list.append(Move{ .source = 4, .target = 2, .piece = piece, .castle = .BQ });
        }
    }
}

pub const Move = struct {
    source: u6,
    target: u6,
    piece: brd.Pieces,
    promotion: Promotion = .X,
    isCapture: bool = false,
    isDoublePush: bool = false,
    isEnPassant: bool = false,
    castle: brd.Castle = .N,

    pub fn isPromotion(self: *Move) bool {
        return self.promotion != .X;
    }

    pub fn isCastle(self: *Move) bool {
        return self.castle != .N;
    }
    pub fn Convert(self: *Move) u24 {
        return @as(u24, self.source) |
            (@as(u24, self.target) << 6) |
            (@as(u24, @intFromEnum(self.piece)) << 12) |
            (@as(u24, @intFromEnum(self.promotion)) << 16) |
            (@as(u24, @intFromBool(self.isCapture)) << 20) |
            (@as(u24, @intFromBool(self.isDoublePush)) << 21) |
            (@as(u24, @intFromBool(self.isEnPassant)) << 22) |
            (@as(u24, @intFromEnum(self.castle)) << 23);
    }
};

pub fn fromU24(encoded: u24) Move {
    const source: u6 = @intCast(encoded & 0x3F);
    const target: u6 = @intCast((encoded >> 6) & 0x3F);
    const piece: brd.Pieces = @enumFromInt((encoded >> 12) & 0xF);
    const promotion: Promotion = @enumFromInt((encoded >> 16) & 0x7);
    const isCapture: bool = (encoded & (1 << 20)) != 0;
    const isDoublePush: bool = (encoded & (1 << 21)) != 0;
    const isEnPassant: bool = (encoded & (1 << 22)) != 0;
    const castle: brd.Castle = @enumFromInt((encoded >> 23) & 0x3);

    return Move{
        .source = source,
        .target = target,
        .piece = piece,
        .promotion = promotion,
        .isCapture = isCapture,
        .isDoublePush = isDoublePush,
        .isEnPassant = isEnPassant,
        .castle = castle,
    };
}
pub const Promotion = enum(u3) { X = 0, Q = 1, R = 2, B = 3, N = 4 };

pub fn MakeMove(move: Move, board: *brd.Board, side: u1) bool {
    const source = if (side == 0) board.GetWhitePieceBitBoard(move.piece) else board.GetBlackPieceBitBoard(move.piece);
    const sourceSquare = try sqr.Square.fromIndex(move.source);
    const epSquare = bit.LeastSignificantBit(board.enPassantSquare);
    bit.PopBit(&board.enPassantSquare, try sqr.Square.fromIndex(@truncate(epSquare)));
    bit.PopBit(source, try sqr.Square.fromIndex(move.source));
    if (move.promotion == .X) {
        bit.SetBit(source, try sqr.Square.fromIndex(move.target));
    }

    if (board.castle > 0 and move.castle == .N) {
        if (side == 0) {
            switch (move.piece) {
                brd.Pieces.K => {
                    board.castle ^= 1;
                    board.castle ^= 2;
                },
                brd.Pieces.R => {
                    if (sourceSquare == .A1) {
                        board.castle ^= 2;
                    } else if (sourceSquare == .H1) {
                        board.castle ^= 1;
                    }
                },
                else => {},
            }
        } else {
            switch (move.piece) {
                brd.Pieces.k => {
                    board.castle ^= 4;
                    board.castle ^= 8;
                },
                brd.Pieces.r => {
                    if (sourceSquare == .A8) {
                        board.castle ^= 8;
                    } else if (sourceSquare == .H8) {
                        board.castle ^= 4;
                    }
                },
                else => {},
            }
        }
    }
    if (move.castle != .N) {
        switch (move.castle) {
            brd.Castle.WK => {
                if ((board.castle & 1) > 0) {
                    bit.PopBit(&board.wRooks, .H1);
                    bit.SetBit(&board.wRooks, .F1);
                    board.castle ^= 1;
                    board.castle ^= 2;
                } else {
                    @panic("Attempted to king side castle.");
                }
            },
            brd.Castle.WQ => {
                if ((board.castle & 2) > 0) {
                    bit.PopBit(&board.wRooks, .A1);
                    bit.SetBit(&board.wRooks, .D1);
                    board.castle ^= 1;
                    board.castle ^= 2;
                } else {
                    @panic("Attempted to Queen side castle.");
                }
            },
            brd.Castle.BK => {
                if ((board.castle & 4) > 0) {
                    bit.PopBit(&board.bRooks, .H8);
                    bit.SetBit(&board.bRooks, .F8);
                    board.castle ^= 4;
                    board.castle ^= 8;
                } else {
                    @panic("Attempted to king side castle");
                }
            },
            brd.Castle.BQ => {
                if ((board.castle & 8) > 0) {
                    bit.PopBit(&board.bRooks, .A8);
                    bit.SetBit(&board.bRooks, .D8);
                    board.castle ^= 4;
                    board.castle ^= 8;
                } else {
                    @panic("Attempted to queenside castle");
                }
            },
            else => @panic("Invalid Castle"),
        }
    }

    if (move.isDoublePush) {
        if (side == 0) {
            bit.SetBit(&board.enPassantSquare, try sqr.Square.fromIndex(move.target + 8));
        } else {
            bit.SetBit(&board.enPassantSquare, try sqr.Square.fromIndex(move.target - 8));
        }
    } else {
        if (move.isCapture) {
            if (side == 0) {
                if (move.isEnPassant) {
                    bit.PopBit(&board.bPawns, try sqr.Square.fromIndex(move.target + 8));
                } else {
                    bit.PopBit(&board.bPawns, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bKnights, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bBishops, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bRooks, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bQueens, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.bKing, try sqr.Square.fromIndex(move.target));
                }
            } else {
                if (move.isEnPassant) {
                    bit.PopBit(&board.wPawns, try sqr.Square.fromIndex(move.target - 8));
                } else {
                    bit.PopBit(&board.wPawns, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wKnights, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wBishops, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wRooks, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wQueens, try sqr.Square.fromIndex(move.target));
                    bit.PopBit(&board.wKing, try sqr.Square.fromIndex(move.target));
                }
            }
        }

        if (move.promotion != .X) {
            if (side == 0) {
                switch (move.promotion) {
                    Promotion.Q => {
                        bit.SetBit(&board.wQueens, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.N => {
                        bit.SetBit(&board.wKnights, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.B => {
                        bit.SetBit(&board.wBishops, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.R => {
                        bit.SetBit(&board.wRooks, try sqr.Square.fromIndex(move.target));
                    },
                    else => @panic("Invalid promotion"),
                }
            } else {
                switch (move.promotion) {
                    Promotion.Q => {
                        bit.SetBit(&board.bQueens, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.N => {
                        bit.SetBit(&board.bKnights, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.B => {
                        bit.SetBit(&board.bBishops, try sqr.Square.fromIndex(move.target));
                    },
                    Promotion.R => {
                        bit.SetBit(&board.bRooks, try sqr.Square.fromIndex(move.target));
                    },
                    else => @panic("Invalid promotion"),
                }
            }
        }
    }
    const kingSquare = if (side == 0) bit.LeastSignificantBit(board.wKing) else bit.LeastSignificantBit(board.bKing);
    if (board.isSquareAttacked(@intCast(kingSquare), side)) {
        return false;
    }

    return true;
}
