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
}

pub fn PawnMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    var bitBoard: u64 = undefined;
    const allPieces: u64 = board.wPieces | board.bPieces;

    if (side == 0) {
        bitBoard = board.wPawns;

        while (bitBoard > 0) {
            const source: u6 = @intCast(bit.LeastSignificantBit(bitBoard));
            bit.PopBit(&bitBoard, try sqr.Square.fromIndex(source));
            if (source == 64) break;

            var target = source - 8;
            if (target < 0) continue;

            const rank: u4 = @intCast(8 - (source / 8));
            var pieceAtTarget: bool = (@as(u64, 1) << target) & allPieces > 0;
            if (!pieceAtTarget) {
                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .castle = .N, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .castle = .N, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .castle = .N, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .castle = .N, .isCapture = false });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });

                    pieceAtTarget = (@as(u64, 1) << target - 8) & allPieces > 0;
                    if (rank == 2 and !pieceAtTarget) {
                        // Double pawn push
                        try list.append(Move{ .source = source, .target = target - 8, .promotion = 0, .castle = .N, .isCapture = false });
                    }
                }
            }

            var attackMap = try map.MaskPawnAttacks(source, 0);
            attackMap &= board.bPieces ^ board.enPassantSquare;
            while (attackMap > 0) {
                target = @intCast(bit.LeastSignificantBit(attackMap));

                bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .castle = .N, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .castle = .N, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .castle = .N, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .castle = .N, .isCapture = true });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
                }
            }
        }
    } else {
        bitBoard = board.bPawns;

        while (bitBoard > 0) {
            const source: u6 = @intCast(bit.LeastSignificantBit(bitBoard));
            bit.PopBit(&bitBoard, try sqr.Square.fromIndex(source));
            if (source == 64) break;

            var target = source + 8;
            if (target > 63) continue;

            const rank: u4 = @intCast(8 - (source / 8));
            var pieceAtTarget: bool = (@as(u64, 1) << target) & allPieces > 0;
            if (!pieceAtTarget) {
                if (rank == 2) {
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .castle = .N, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .castle = .N, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .castle = .N, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .castle = .N, .isCapture = false });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });

                    pieceAtTarget = (@as(u64, 1) << target + 8) & allPieces > 0;
                    if (rank == 7 and !pieceAtTarget) {
                        // Double pawn push
                        try list.append(Move{ .source = source, .target = target + 8, .promotion = 0, .castle = .N, .isCapture = false });
                    }
                }
            }

            var attackMap = try map.MaskPawnAttacks(source, 1);
            attackMap &= board.wPieces ^ board.enPassantSquare;

            while (attackMap > 0) {
                target = @intCast(bit.LeastSignificantBit(attackMap));

                bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .castle = .N, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .castle = .N, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .castle = .N, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .castle = .N, .isCapture = true });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
                }
            }
        }
    }
}

pub fn KnightMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    var knights = if (side == 0) board.wKnights else board.bKnights;
    const pieces = if (side == 0) board.wPieces else board.bPieces;
    const enemyPieces = if (side == 0) board.bPieces else board.wPieces;
    while (knights > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(knights));
        bit.PopBit(&knights, try sqr.Square.fromIndex(source));
        var targets = try map.MaskKnightAttacks(source) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });
            }
        }
    }
}

pub fn BishopMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    var bishops = if (side == 0) board.wBishops else board.bBishops;
    const allPieces = board.wPieces | board.bPieces;
    const pieces = if (side == 0) board.wPieces else board.bPieces;
    const enemyPieces = if (side == 0) board.bPieces else board.wPieces;
    while (bishops > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(bishops));
        bit.PopBit(&bishops, try sqr.Square.fromIndex(source));
        var targets = map.GetBishopAttacks(source, allPieces) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });
            }
        }
    }
}

pub fn RookMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    var rooks = if (side == 0) board.wRooks else board.bRooks;
    const allPieces = board.wPieces | board.bPieces;
    const pieces = if (side == 0) board.wPieces else board.bPieces;
    const enemyPieces = if (side == 0) board.bPieces else board.wPieces;
    while (rooks > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(rooks));
        bit.PopBit(&rooks, try sqr.Square.fromIndex(source));
        var targets = map.GetRookAttacks(source, allPieces) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });
            }
        }
    }
}

pub fn QueenMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    var queens = if (side == 0) board.wQueens else board.bQueens;
    const allPieces = board.wPieces | board.bPieces;
    const pieces = if (side == 0) board.wPieces else board.bPieces;
    const enemyPieces = if (side == 0) board.bPieces else board.wPieces;
    while (queens > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(queens));
        bit.PopBit(&queens, try sqr.Square.fromIndex(source));
        const rookTargets = map.GetRookAttacks(source, allPieces) & ~pieces;
        const bishopTargets = map.GetBishopAttacks(source, allPieces) & ~pieces;
        var targets = rookTargets | bishopTargets;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });
            }
        }
    }
}

pub fn KingMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    var king = if (side == 0) board.wKing else board.bKing;
    const pieces = if (side == 0) board.wPieces else board.bPieces;
    const enemyPieces = if (side == 0) board.bPieces else board.wPieces;
    while (king > 0) {
        const source: u6 = @intCast(bit.LeastSignificantBit(king));
        bit.PopBit(&king, try sqr.Square.fromIndex(source));
        var targets = try map.MaskKingAttacks(source) & ~pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.LeastSignificantBit(targets));
            const targetSquare = @as(u64, 1) << target;
            bit.PopBit(&targets, try sqr.Square.fromIndex(target));

            if (targetSquare & enemyPieces > 0) {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .castle = .N, .isCapture = false });
            }
        }
    }
}

pub fn CastleMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    const rooks = if (side == 0) board.wRooks else board.bRooks;
    const king = if (side == 0) board.wKing else board.bKing;
    const atHomeSquare: bool = (side == 1 and king == (1 << 4)) or (side == 0 and king == (1 << 60));
    const allPieces = board.wPieces | board.bPieces;
    if (!atHomeSquare) return;

    if (side == 0) {
        const kingSideRook: bool = (rooks & (map.FILE_H & map.RANK_1)) > 0;
        const queenSideRook: bool = (rooks & (map.FILE_A & map.RANK_1)) > 0;
        const b1 = sqr.Square.toIndex(.B1);
        const c1 = sqr.Square.toIndex(.C1);
        const d1 = sqr.Square.toIndex(.D1);
        const f1 = sqr.Square.toIndex(.F1);
        const g1 = sqr.Square.toIndex(.G1);
        const kingSideCastleEmpty = bit.GetBit(allPieces, f1) == 0 and bit.GetBit(allPieces, g1) == 0;
        const kingSideCastleAttacked = board.isSquareAttacked(f1, 0) or board.isSquareAttacked(g1, 0);
        const queenSideCastleEmpty = bit.GetBit(allPieces, b1) == 0 and bit.GetBit(allPieces, c1) == 0 and bit.GetBit(allPieces, d1) == 0;
        const queenSideCastleAttacked = board.isSquareAttacked(b1, 0) or board.isSquareAttacked(c1, 0) or board.isSquareAttacked(d1, 0);

        if (kingSideRook and kingSideCastleEmpty and !kingSideCastleAttacked) {
            try list.append(Move{ .source = 60, .target = 62, .promotion = 0, .castle = .WK, .isCapture = false });
        }
        if (queenSideRook and queenSideCastleEmpty and !queenSideCastleAttacked) {
            try list.append(Move{ .source = 60, .target = 58, .promotion = 0, .castle = .WQ, .isCapture = false });
        }
    } else {
        const kingSideRook: bool = (rooks & (map.FILE_H & map.RANK_8)) > 0;
        const queenSideRook: bool = (rooks & (map.FILE_A & map.RANK_8)) > 0;
        const b8 = sqr.Square.toIndex(.B8);
        const c8 = sqr.Square.toIndex(.C8);
        const d8 = sqr.Square.toIndex(.D8);
        const f8 = sqr.Square.toIndex(.F8);
        const g8 = sqr.Square.toIndex(.G8);
        const kingSideCastleEmpty = bit.GetBit(allPieces, f8) == 0 and bit.GetBit(allPieces, g8) == 0;
        const kingSideCastleAttacked = board.isSquareAttacked(f8, 1) or board.isSquareAttacked(g8, 1);
        const queenSideCastleEmpty = bit.GetBit(allPieces, b8) == 0 and bit.GetBit(allPieces, c8) == 0 and bit.GetBit(allPieces, d8) == 0;
        const queenSideCastleAttacked = board.isSquareAttacked(b8, 1) or board.isSquareAttacked(c8, 1) or board.isSquareAttacked(d8, 1);

        if (kingSideRook and kingSideCastleEmpty and !kingSideCastleAttacked) {
            try list.append(Move{ .source = 4, .target = 6, .promotion = 0, .castle = .BK, .isCapture = false });
        }
        if (queenSideRook and queenSideCastleEmpty and !queenSideCastleAttacked) {
            try list.append(Move{ .source = 4, .target = 2, .promotion = 0, .castle = .BQ, .isCapture = false });
        }
    }
}

pub const Move = struct {
    source: u6,
    target: u6,
    promotion: u3,
    castle: brd.Castle,
    isCapture: bool,

    pub fn isPromotion(self: *Move) bool {
        return self.promotion != 0;
    }

    pub fn isCastle(self: *Move) bool {
        return self.Castle != .N;
    }
};

pub const Promotion = enum(u3) { Q = 1, R = 2, B = 3, N = 4 };
