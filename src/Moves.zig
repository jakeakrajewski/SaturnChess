const std = @import("std");
const brd = @import("Board.zig");
const map = @import("Maps.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const zob = @import("Zobrist.zig");

pub var pin_mask: u64 = 0;
pub var check_mask: u64 = 0;
pub var board: *brd.Board = undefined;
pub var side: u1 = 0;
pub var list: *std.ArrayList(Move) = undefined;
var captures_only = false;

pub inline fn generateMoves(move_list: *std.ArrayList(Move), b: *brd.Board, s: u1) !void {
    board = b;
    side = s;
    list = move_list;
    captures_only = false;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    const attackers = board.isSquareAttacked(king_square, side);
    pin_mask = getPinMask();
    check_mask = 0;

    if (attackers > 0) {
        check_mask = getCheckMask();
    }

    if (attackers > 1) {
        try kingMoves();
    } else {
        try pawnMoves();
        try pieceMoves();
        if (attackers == 0) {
            try castleMoves();
        }
    }
}

pub inline fn generateCaptures(move_list: *std.ArrayList(Move), b: *brd.Board, s: u1) !void {
    board = b;
    side = s;
    list = move_list;
    captures_only = true;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    const attackers = board.isSquareAttacked(king_square, side);
    pin_mask = getPinMask();
    check_mask = 0;

    if (attackers > 0) {
        check_mask = getCheckMask();
    }

    if (attackers > 1) {
        try kingMoves();
    } else {
        try pawnMoves();
        try pieceMoves();
    }
}

pub inline fn getPinMask() u64 {
    var b = board;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const pieces = if (side == 0) b.wPieces() else b.bPieces();
    const opponent_pieces = if (side == 0) b.bPieces() else b.wPieces();
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    const bishop_pin_mask: u64 = map.getBishopAttacks(king_square, opponent_pieces);
    const rook_pin_mask: u64 = map.getRookAttacks(king_square, opponent_pieces);
    var bishops = (if (side == 0) board.bBishops else board.wBishops) & bishop_pin_mask;
    var rooks = (if (side == 0) board.bRooks else board.wRooks) & rook_pin_mask;
    var queens = (if (side == 0) board.bQueens else board.wQueens) & (rook_pin_mask | bishop_pin_mask);

    var bishop_mask: u64 = 0;
    var rook_mask: u64 = 0;
    var queen_bishop_mask: u64 = 0;
    var queen_rook_mask: u64 = 0;

    while (bishops > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(bishops));
        const source_board: u64 = @as(u64, 1) << source;
        const bishop_check = (source_board & map.getBishopAttacks(king_square, b.allPieces()));

        if (bishop_check > 0) {
            bit.popBit(&bishops, source);
            continue;
        }

        if ((source_board & map.getBishopAttacks(king_square, opponent_pieces)) > 0) {
            bishop_mask |= map.getBishopAttacks(source, pieces);
        }
        bit.popBit(&bishops, source);
        bishop_mask &= map.getBishopAttacks(king_square, source_board);
    }

    while (rooks > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(rooks));
        const source_board: u64 = @as(u64, 1) << source;
        const rook_check = (source_board & map.getRookAttacks(king_square, b.allPieces()));

        if (rook_check > 0) {
            bit.popBit(&rooks, source);
            continue;
        }

        if ((source_board & map.getRookAttacks(king_square, opponent_pieces)) > 0) {
            rook_mask |= map.getRookAttacks(source, pieces);
        }
        bit.popBit(&rooks, source);
        rook_mask &= map.getRookAttacks(king_square, source_board);
    }

    while (queens > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(queens));
        const source_board: u64 = @as(u64, 1) << source;

        const bishop_check = (source_board & map.getBishopAttacks(king_square, b.allPieces()));
        const rook_check = (source_board & map.getRookAttacks(king_square, b.allPieces()));

        if (bishop_check > 0 or rook_check > 0) {
            bit.popBit(&queens, source);
            continue;
        }

        if ((source_board & map.getBishopAttacks(king_square, opponent_pieces)) > 0) {
            queen_bishop_mask |= map.getBishopAttacks(source, pieces);
        }
        if ((source_board & map.getRookAttacks(king_square, opponent_pieces)) > 0) {
            queen_rook_mask |= map.getRookAttacks(source, pieces);
        }

        bit.popBit(&queens, source);
        queen_rook_mask &= map.getRookAttacks(king_square, source_board);
        queen_bishop_mask &= map.getBishopAttacks(king_square, source_board);
    }

    return bishop_mask | rook_mask | queen_rook_mask | queen_bishop_mask;
}

pub inline fn getCheckMask() u64 {
    const opponent_side: u1 = if (side == 0) 1 else 0;
    var pawns = if (side == 0) board.bPawns else board.wPawns;
    var knights = if (side == 0) board.bKnights else board.wKnights;
    var bishops = if (side == 0) board.bBishops else board.wBishops;
    var rooks = if (side == 0) board.bRooks else board.wRooks;
    var queens = if (side == 0) board.bQueens else board.wQueens;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    var b = board;

    var mask: u64 = 0;

    while (pawns > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(pawns));
        const attack_mask = map.pawn_attacks[opponent_side][source];
        const source_board: u64 = @as(u64, 1) << source;
        if ((attack_mask & king_board) > 0) mask |= source_board;
        bit.popBit(&pawns, source);
    }
    while (knights > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(knights));
        const attack_mask = map.knight_attacks[source];
        const source_board: u64 = @as(u64, 1) << source;
        if ((attack_mask & king_board) > 0) mask |= source_board;
        bit.popBit(&knights, source);
    }
    while (bishops > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(bishops));
        const king_sliders = map.getBishopAttacks(king_square, bishops);
        const attack_mask = map.getBishopAttacks(source, b.allPieces());
        const source_board: u64 = (@as(u64, 1) << source) | attack_mask;
        if ((attack_mask & king_board) > 0) mask |= source_board & king_sliders;
        bit.popBit(&bishops, source);
    }
    while (rooks > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(rooks));
        const king_sliders = map.getRookAttacks(king_square, rooks);
        const attack_mask = map.getRookAttacks(source, b.allPieces());
        const source_board: u64 = (@as(u64, 1) << source) | attack_mask;
        if ((attack_mask & king_board) > 0) mask |= source_board & king_sliders;
        bit.popBit(&rooks, source);
    }
    while (queens > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(queens));
        var king_sliders = map.getBishopAttacks(king_square, queens);
        var attack_mask = map.getBishopAttacks(source, b.allPieces());
        var source_board: u64 = (@as(u64, 1) << source) | attack_mask;
        if ((attack_mask & king_board) > 0) mask |= source_board & king_sliders;
        king_sliders = map.getRookAttacks(king_square, queens);
        attack_mask = map.getRookAttacks(source, b.allPieces());
        source_board = (@as(u64, 1) << source) | attack_mask;
        if ((attack_mask & king_board) > 0) mask |= source_board & king_sliders;
        bit.popBit(&queens, source);
    }

    return mask;
}

pub inline fn pawnMoves() !void {
    const piece = if (side == 0) brd.Pieces.P else brd.Pieces.p;
    const direction: i8 = if (side == 0) -8 else 8;
    const promotion_rank: u4 = if (side == 0) 7 else 2;
    const double_rank: u4 = if (side == 0) 2 else 7;
    var bitBoard: u64 = if (side == 0) board.wPawns else board.bPawns;
    const opponent_pieces: u64 = if (side == 0) board.bPieces() else board.wPieces();
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));

    while (bitBoard > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(bitBoard));
        const ep_square: u6 = @truncate(bit.leastSignificantBit(board.enPassantSquare));
        bit.popBit(&bitBoard, source);
        if (source == 64) break;

        const rank: u4 = @intCast(8 - (source / 8));
        var target: u6 = @intCast(source + direction);
        if (target < 0) continue;

        var target_board = @as(u64, 1) << target;
        if (!captures_only) {
            const source_board = @as(u64, 1) << source;
            const double_board = if (rank == double_rank) @as(u64, 1) << @intCast(target + direction) else 0;
            var single_possible = true;
            var double_possible = true;
            var piece_pinned = false;

            if (check_mask > 0) {
                if ((check_mask & target_board) == 0) single_possible = false;
                if ((check_mask & double_board) == 0) double_possible = false;
            }

            if ((pin_mask & source_board) > 0) {
                var board_copy = board.*;
                if (side == 0) {
                    bit.popBit(&board_copy.wPawns, source);
                    bit.setBit(&board_copy.wPawns, target);
                } else {
                    bit.popBit(&board_copy.bPawns, source);
                    bit.setBit(&board_copy.bPawns, target);
                }

                if (board_copy.isSquareAttacked(king_square, side) > 0) piece_pinned = true;
            }

            var piece_at_target: bool = target_board & board.allPieces() > 0;
            if (!piece_at_target and !piece_pinned) {
                if (rank == promotion_rank and single_possible) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B });
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N });
                } else {
                    if (single_possible) {
                        try list.append(Move{ .source = source, .target = target, .piece = piece });
                    }

                    if (rank == double_rank and double_possible) {
                        // Double pawn push
                        piece_at_target = bit.getBit(board.allPieces(), @intCast(target + direction)) > 0;
                        if (!piece_at_target) {
                            try list.append(Move{ .source = source, .target = @intCast(target + direction), .piece = piece, .isDoublePush = true });
                        }
                    }
                }
            }
        }

        var attack_map = map.pawn_attacks[side][source];
        attack_map &= (opponent_pieces | board.enPassantSquare);
        while (attack_map > 0) {
            target = @intCast(bit.leastSignificantBit(attack_map));
            target_board = @as(u64, 1) << target;
            bit.popBit(&attack_map, @intCast(target));

            var board_copy = board.*;
            board_copy.updateBoard(piece, source, target, side, target == ep_square);
            if (board_copy.isSquareAttacked(king_square, side) > 0) continue;

            if (rank == promotion_rank) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .Q, .isCapture = true });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .R, .isCapture = true });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .B, .isCapture = true });
                try list.append(Move{ .source = source, .target = target, .piece = piece, .promotion = .N, .isCapture = true });
            } else {
                if (target == ep_square) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true, .isEnPassant = true });
                } else {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
                }
            }
        }
    }
}

pub inline fn pieceMoves() !void {
    const piece_list: [5]brd.Pieces = if (side == 0) [5]brd.Pieces{ .N, .B, .R, .Q, .K } else [5]brd.Pieces{ .n, .b, .r, .q, .k };
    const occupancy = if (side == 0) board.wPieces() else board.bPieces();
    const opponent_pieces = board.allPieces() ^ occupancy;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));

    for (0..5) |index| {
        const piece = piece_list[index];
        var bitBoard = board.getPieceBitBoard(piece).*;

        while (bitBoard > 0) {
            const source: u6 = @intCast(bit.leastSignificantBit(bitBoard));
            const source_board = @as(u64, 1) << source;
            bit.popLSB(&bitBoard);
            var targets = board.getPieceAttacks(piece, source, side);
            if (captures_only) targets &= opponent_pieces;

            if (check_mask > 0 and piece != .K and piece != .k) {
                targets &= check_mask;
            }

            while (targets > 0) {
                const target: u6 = @intCast(bit.leastSignificantBit(targets));
                bit.popBit(&targets, target);
                const target_board = @as(u64, 1) << target;

                if (check_mask > 0 and piece != .K and piece != .k) {
                    if (check_mask & target_board == 0) {
                        continue;
                    }
                }

                if ((pin_mask & source_board) > 0 or piece == .K or piece == .k) {
                    var board_copy = board.*;
                    board_copy.updateBoard(piece, source, target, side, false);
                    if (piece == .K or piece == .k) {
                        if (board_copy.isSquareAttacked(target, side) > 0) continue;
                    } else {
                        if (board_copy.isSquareAttacked(king_square, side) > 0) continue;
                    }
                }

                if (target_board & opponent_pieces > 0) {
                    try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
                } else {
                    try list.append(Move{ .source = source, .target = target, .piece = piece });
                }
            }
        }
    }
}

pub inline fn kingMoves() !void {
    const piece = if (side == 0) brd.Pieces.K else brd.Pieces.k;
    var king = if (side == 0) board.wKing else board.bKing;
    const pieces = if (side == 0) board.wPieces() else board.bPieces();
    const opponent_pieces = if (side == 0) board.bPieces() else board.wPieces();
    while (king > 0) {
        const source: u6 = @intCast(bit.leastSignificantBit(king));
        bit.popBit(&king, source);
        var targets = try map.maskKingAttacks(source) & ~pieces;
        if (captures_only) targets &= opponent_pieces;
        while (targets > 0) {
            const target: u6 = @intCast(bit.leastSignificantBit(targets));
            const target_square = @as(u64, 1) << target;
            bit.popBit(&targets, target);

            var board_copy = board.*;

            if (side == 0) {
                bit.popBit(&board_copy.wKing, source);
            } else {
                bit.popBit(&board_copy.bKing, source);
            }

            const attackers = board_copy.isSquareAttacked(target, side);
            if (attackers > 0) continue;

            if (target_square & opponent_pieces > 0) {
                try list.append(Move{ .source = source, .target = target, .piece = piece, .isCapture = true });
            } else {
                try list.append(Move{ .source = source, .target = target, .piece = piece });
            }
        }
    }
}

pub inline fn castleMoves() !void {
    const piece = if (side == 0) brd.Pieces.K else brd.Pieces.k;
    const rooks = if (side == 0) board.wRooks else board.bRooks;
    const king = if (side == 0) board.wKing else board.bKing;
    const at_home_square: bool = (side == 1 and king == (1 << 4)) or (side == 0 and king == (1 << 60));
    if (!at_home_square) return;

    if (side == 0) {
        const king_side_rook: bool = (rooks & (map.FILE_H & map.RANK_1)) > 0;
        const queen_side_rook: bool = (rooks & (map.FILE_A & map.RANK_1)) > 0;
        const b1 = sqr.Square.toIndex(.B1);
        const c1 = sqr.Square.toIndex(.C1);
        const d1 = sqr.Square.toIndex(.D1);
        const f1 = sqr.Square.toIndex(.F1);
        const g1 = sqr.Square.toIndex(.G1);
        if (board.castle & 1 > 0) {
            const king_side_castle_empty = bit.getBit(board.allPieces(), f1) == 0 and bit.getBit(board.allPieces(), g1) == 0;
            const king_side_castle_attacked = board.isSquareAttacked(f1, 0) > 0 or board.isSquareAttacked(g1, 0) > 0;
            if (king_side_rook and king_side_castle_empty and !king_side_castle_attacked) {
                try list.append(Move{
                    .source = 60,
                    .target = 62,
                    .piece = piece,
                    .castle = .WK,
                });
            }
        }
        if (board.castle & 2 > 0) {
            const queen_side_castle_empty = bit.getBit(board.allPieces(), b1) == 0 and bit.getBit(board.allPieces(), c1) == 0 and bit.getBit(board.allPieces(), d1) == 0;
            const queen_side_castle_attacked = board.isSquareAttacked(c1, 0) > 0 or board.isSquareAttacked(d1, 0) > 0;
            if (queen_side_rook and queen_side_castle_empty and !queen_side_castle_attacked) {
                try list.append(Move{
                    .source = 60,
                    .target = 58,
                    .piece = piece,
                    .castle = .WQ,
                });
            }
        }
    } else {
        const king_side_rook: bool = (rooks & (map.FILE_H & map.RANK_8)) > 0;
        const queen_side_rook: bool = (rooks & (map.FILE_A & map.RANK_8)) > 0;
        const b8 = sqr.Square.toIndex(.B8);
        const c8 = sqr.Square.toIndex(.C8);
        const d8 = sqr.Square.toIndex(.D8);
        const f8 = sqr.Square.toIndex(.F8);
        const g8 = sqr.Square.toIndex(.G8);
        if (board.castle & 4 > 0) {
            const king_side_castle_empty = bit.getBit(board.allPieces(), f8) == 0 and bit.getBit(board.allPieces(), g8) == 0;
            const king_side_castle_attacked = board.isSquareAttacked(f8, 1) > 0 or board.isSquareAttacked(g8, 1) > 0;
            if (king_side_rook and king_side_castle_empty and !king_side_castle_attacked) {
                try list.append(Move{ .source = 4, .target = 6, .piece = piece, .castle = .BK });
            }
        }
        if (board.castle & 8 > 0) {
            const queen_side_castle_empty = bit.getBit(board.allPieces(), b8) == 0 and bit.getBit(board.allPieces(), c8) == 0 and bit.getBit(board.allPieces(), d8) == 0;
            const queen_side_castle_attacked = board.isSquareAttacked(c8, 1) > 0 or board.isSquareAttacked(d8, 1) > 0;
            if (queen_side_rook and queen_side_castle_empty and !queen_side_castle_attacked) {
                try list.append(Move{ .source = 4, .target = 2, .piece = piece, .castle = .BQ });
            }
        }
    }
}

pub const Move = packed struct {
    source: u6,
    target: u6,
    piece: brd.Pieces,
    promotion: Promotion = .X,
    isCapture: bool = false,
    isCheck: bool = false,
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

    pub fn Equals(self: *Move, other: Move) bool {
        if (self.source == other.source and self.target == other.target and self.piece == other.piece) return true;
        return false;
    }

    pub fn promotionChar(self: *Move) []const u8 {
        switch (self.promotion) {
            .X => return "",
            .N => return "n",
            .B => return "b",
            .R => return "r",
            .Q => return "q",
        }
    }
};

pub fn FromU24(encoded: u24) Move {
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

pub inline fn makeMove(move: Move, b: *brd.Board, s: u1) bool {
    board = b;
    side = s;
    const source = board.getPieceBitBoard(move.piece);
    const source_square = move.source;
    const target_square = move.target;
    const ep_square = bit.leastSignificantBit(board.enPassantSquare);
    bit.popBit(&board.enPassantSquare, @truncate(ep_square));
    bit.popBit(source, move.source);
    if (move.promotion == .X) {
        bit.setBit(source, move.target);
    }

    if (board.castle > 0 and move.castle == .N) {
        if (side == 0) {
            switch (move.piece) {
                .K => {
                    if (board.castle & 1 > 0) board.castle ^= 1;
                    if (board.castle & 2 > 0) board.castle ^= 2;
                },
                .R => {
                    if (source_square == 56) {
                        if (board.castle & 2 > 0) board.castle ^= 2;
                    } else if (source_square == 63) {
                        if (board.castle & 1 > 0) board.castle ^= 1;
                    }
                },
                else => {},
            }
        } else {
            switch (move.piece) {
                .k => {
                    if (board.castle & 4 > 0) board.castle ^= 4;
                    if (board.castle & 8 > 0) board.castle ^= 8;
                },
                .r => {
                    if (source_square == 0) {
                        if (board.castle & 8 > 0) board.castle ^= 8;
                    } else if (source_square == 7) {
                        if (board.castle & 4 > 0) board.castle ^= 4;
                    }
                },
                else => {},
            }
        }

        switch (target_square) {
            0 => {
                if (board.castle & 8 > 0) board.castle ^= 8;
            },
            7 => {
                if (board.castle & 4 > 0) board.castle ^= 4;
            },
            56 => {
                if (board.castle & 2 > 0) board.castle ^= 2;
            },
            63 => {
                if (board.castle & 1 > 0) board.castle ^= 1;
            },
            else => {},
        }
    }

    if (move.castle != .N) {
        switch (move.castle) {
            .WK => {
                if ((board.castle & 1) > 0) {
                    bit.popBit(&board.wRooks, 63);
                    bit.setBit(&board.wRooks, 61);
                    board.castle ^= 1;
                    board.castle ^= 2;
                } else {
                    @panic("Attempted to king side castle.");
                }
            },
            .WQ => {
                if ((board.castle & 2) > 0) {
                    bit.popBit(&board.wRooks, 56);
                    bit.setBit(&board.wRooks, 59);
                    board.castle ^= 1;
                    board.castle ^= 2;
                } else {
                    @panic("Attempted to Queen side castle.");
                }
            },
            .BK => {
                if ((board.castle & 4) > 0) {
                    bit.popBit(&board.bRooks, 7);
                    bit.setBit(&board.bRooks, 5);
                    board.castle ^= 4;
                    board.castle ^= 8;
                } else {
                    @panic("Attempted to king side castle");
                }
            },
            .BQ => {
                if ((board.castle & 8) > 0) {
                    bit.popBit(&board.bRooks, 0);
                    bit.setBit(&board.bRooks, 3);
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
            bit.setBit(&board.enPassantSquare, move.target + 8);
        } else {
            bit.setBit(&board.enPassantSquare, move.target - 8);
        }
    } else {
        // if (move.isCapture) {
        if (side == 0) {
            if (move.isEnPassant) {
                bit.popBit(&board.bPawns, move.target + 8);
            } else {
                bit.popBit(&board.bPawns, move.target);
                bit.popBit(&board.bKnights, move.target);
                bit.popBit(&board.bBishops, move.target);
                bit.popBit(&board.bRooks, move.target);
                bit.popBit(&board.bQueens, move.target);
                bit.popBit(&board.bKing, move.target);
            }
        } else {
            if (move.isEnPassant) {
                bit.popBit(&board.wPawns, move.target - 8);
            } else {
                bit.popBit(&board.wPawns, move.target);
                bit.popBit(&board.wKnights, move.target);
                bit.popBit(&board.wBishops, move.target);
                bit.popBit(&board.wRooks, move.target);
                bit.popBit(&board.wQueens, move.target);
                bit.popBit(&board.wKing, move.target);
            }
        }
        // }

        if (move.promotion != .X) {
            if (side == 0) {
                switch (move.promotion) {
                    .Q => {
                        bit.setBit(&board.wQueens, move.target);
                    },
                    .N => {
                        bit.setBit(&board.wKnights, move.target);
                    },
                    .B => {
                        bit.setBit(&board.wBishops, move.target);
                    },
                    .R => {
                        bit.setBit(&board.wRooks, move.target);
                    },
                    else => @panic("Invalid promotion"),
                }
            } else {
                switch (move.promotion) {
                    .Q => {
                        bit.setBit(&board.bQueens, move.target);
                    },
                    .N => {
                        bit.setBit(&board.bKnights, move.target);
                    },
                    .B => {
                        bit.setBit(&board.bBishops, move.target);
                    },
                    .R => {
                        bit.setBit(&board.bRooks, move.target);
                    },
                    else => @panic("Invalid promotion"),
                }
            }
        }
    }
    const king_square = if (side == 0) bit.leastSignificantBit(board.wKing) else bit.leastSignificantBit(board.bKing);
    if (board.isSquareAttacked(@intCast(king_square), side) > 0) {
        return false;
    }
    board.sideToMove = ~side;
    zob.generateHashKey(board);

    return true;
}
