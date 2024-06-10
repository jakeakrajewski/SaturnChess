const std = @import("std");
const brd = @import("../Game/Board.zig");
const map = @import("../Maps/Maps.zig");
const bit = @import("../BitManipulation/BitManipulation.zig");
const sqr = @import("../Board/Square.zig");

pub fn GenerateMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) !void {
    // try PawnMoves(list, board, side);
    // try KnightMoves(list, board, side);
    try BishopMoves(list, board, side);
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
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .isCapture = false });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = false });

                    pieceAtTarget = (@as(u64, 1) << target - 8) & allPieces > 0;
                    if (rank == 2 and !pieceAtTarget) {
                        // Double pawn push
                        try list.append(Move{ .source = source, .target = target - 8, .promotion = 0, .isCapture = false });
                    }
                }
            }

            var attackMap = try map.MaskPawnAttacks(source, 0);
            attackMap &= board.bPieces ^ board.enPassantSquare;
            while (attackMap > 0) {
                target = @intCast(bit.LeastSignificantBit(attackMap));

                bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .isCapture = true });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = true });
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
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .isCapture = false });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .isCapture = false });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = false });

                    pieceAtTarget = (@as(u64, 1) << target + 8) & allPieces > 0;
                    if (rank == 7 and !pieceAtTarget) {
                        // Double pawn push
                        try list.append(Move{ .source = source, .target = target + 8, .promotion = 0, .isCapture = false });
                    }
                }
            }

            var attackMap = try map.MaskPawnAttacks(source, 1);
            attackMap &= board.wPieces ^ board.enPassantSquare;

            while (attackMap > 0) {
                target = @intCast(bit.LeastSignificantBit(attackMap));

                bit.PopBit(&attackMap, try sqr.Square.fromIndex(@intCast(target)));

                if (rank == 7) {
                    try list.append(Move{ .source = source, .target = target, .promotion = 1, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 2, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 3, .isCapture = true });
                    try list.append(Move{ .source = source, .target = target, .promotion = 4, .isCapture = true });
                } else {
                    try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = true });
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
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = false });
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
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .promotion = 0, .isCapture = false });
            }
        }
    }
}
// pub fn BishopMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) void {}
// pub fn RookMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) void {}
// pub fn QueenMoves(list: *std.ArrayList(Move), board: *brd.Board, side: u1) void {}

pub const Move = struct {
    source: u6,
    target: u6,
    promotion: u3,
    isCapture: bool,

    pub fn isPromotion(self: *Move) bool {
        return self.promotion != 0;
    }
};

pub const Promotion = enum(u3) { Q = 1, R = 2, B = 3, N = 4 };
