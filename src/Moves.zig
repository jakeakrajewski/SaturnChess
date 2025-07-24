const std = @import("std");
const brd = @import("Board.zig");
const map = @import("Maps.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const zob = @import("Zobrist.zig");

pub var pin_masks: [64]u64 = [_]u64{0} ** 64; // Clear every move gen

pub var check_mask: u64 = 0;
pub var board: *brd.Board = undefined;
pub var side: u1 = 0;
pub var list: *std.ArrayList(Move) = undefined;
var captures_only = false;

pub inline fn rayBetween(a: u6, b: u6) u64 {
    return map.ray_between[a][b];
}

pub fn generateMoves(move_list: *std.ArrayList(Move), b: *brd.Board, s: u1) !void {
    board = b;
    side = s;
    list = move_list;
    captures_only = false;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    const attackers = board.isSquareAttacked(king_square, side);
    pin_masks = [_]u64{0} ** 64; // Clear every move gen
    getPinMask();
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

pub fn generateCaptures(move_list: *std.ArrayList(Move), b: *brd.Board, s: u1) !void {
    board = b;
    side = s;
    list = move_list;
    captures_only = true;
    const king_board = if (side == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    const attackers = board.isSquareAttacked(king_square, side);
    getPinMask();
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


pub fn getPinMask() void {
    @memset(&pin_masks, 0);
    const king_square: u6 = @intCast(bit.leastSignificantBit(if (side == 0) board.wKing else board.bKing));
    const own_pieces = if (side == 0) board.wPieces() else board.bPieces();
    const opp_pieces = if (side == 0) board.bPieces() else board.wPieces();
    const opp_bish_queen = (if (side == 0) board.bBishops | board.bQueens else board.wBishops | board.wQueens);
    const opp_rook_queen = (if (side == 0) board.bRooks | board.bQueens else board.wRooks | board.wQueens);

    // const all_pieces = board.allPieces();

    // Sliding directions (bishop + rook)
    const directions = [_]fn(u6, u64) u64{
        map.getBishopAttacks,
        map.getRookAttacks,
    };

    const sliders = [_]u64{ opp_bish_queen, opp_rook_queen };

    inline for (directions, sliders) |getAttacks, enemy_sliders| {
        var attacks = getAttacks(king_square, opp_pieces) & enemy_sliders;

        while (attacks != 0) {
            const attacker_square: u6 = @intCast(bit.leastSignificantBit(attacks));
            bit.popBit(&attacks, attacker_square);

            const ray = rayBetween(king_square, attacker_square) | (@as(u64, 1) << attacker_square);
            const blockers = ray & own_pieces;

            if (bit.bitCount(blockers) == 1) {
                const pinned_sq: u6 = @intCast(bit.leastSignificantBit(blockers));
                // Piece at pinned_sq is pinned along this ray
                pin_masks[pinned_sq] = ray;
            }
        }
    }
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
    const pawns: u64 = if (side == 0) board.wPawns else board.bPawns;
    const their_pieces = if (side == 0) board.bPieces() else board.wPieces();
    const empty = ~board.allPieces();
    const rank7: u64 = if (side == 0)
        @as(u64, 0x00FF000000000000)
    else
        @as(u64, 0x000000000000FF00);
    const rank2: u64 = if (side == 0)
        @as(u64, 0x00FF000000000000)
    else
        @as(u64, 0x000000000000FF00);

    const king_sq: u6 = @intCast(bit.leastSignificantBit(if (side == 0) board.wKing else board.bKing));
    const ep_sq: u6 = @truncate(bit.leastSignificantBit(board.enPassantSquare));
    const ep_bb: u64 = board.enPassantSquare;

    const forward_shift: isize = if (side == 0) -8 else 8;
    const double_shift: isize = if (side == 0) -16 else 16;

    // -------------------
    // Single pushes
    // -------------------
    const single_pushes = if (side == 0)
        (pawns >> 8) & empty
    else
        (pawns << 8) & empty;

    var single = single_pushes;
    if (check_mask > 0){
        single &= check_mask;
    }

    while (single != 0) {
        const to: u6 = @intCast(bit.leastSignificantBit(single));
        const from: u6 = @intCast(@as(i16, to) - forward_shift);
        bit.popBit(&single, to);

        if (pin_masks[from] != 0 and (pin_masks[from] & (@as(u64, 1) << to)) == 0)
            continue;

        const is_promo = ((@as(u64, 1) << to) & rank7) != 0;
        if (is_promo) {
            try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .Q });
            try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .R });
            try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .B });
            try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .N });
        } else {
            try list.append(.{ .source = from, .target = to, .piece = piece });
        }
    }

    // -------------------
    // Double pushes
    // -------------------
    var doubles = if (side == 0)
        (((pawns & rank2) >> 8) & empty) >> 8 & empty
    else
        (((pawns & rank2) << 8) & empty) << 8 & empty;

    if (check_mask > 0){
        doubles &= check_mask;
    }
    while (doubles != 0) {
        const to: u6 = @intCast(bit.leastSignificantBit(doubles));
        const from: u6 = @intCast(@as(i16, to) - double_shift);
        bit.popBit(&doubles, to);

        if (pin_masks[from] != 0 and (pin_masks[from] & (@as(u64, 1) << to)) == 0)
            continue;

        try list.append(.{ .source = from, .target = to, .piece = piece, .isDoublePush = true });
    }

    // -------------------
    // Captures
    // -------------------
    const left: u64 = if (side == 0)
        (pawns >> 7) & ~@as(u64, 0x8080808080808080)
    else
        (pawns << 9) & ~@as(u64, 0x0101010101010101);

    const right: u64 = if (side == 0)
        (pawns >> 9) & ~@as(u64, 0x0101010101010101)
    else
        (pawns << 7) & ~@as(u64, 0x8080808080808080);

    const attacks = (left | right) & (their_pieces | ep_bb) & check_mask;

    var captures = attacks;
    while (captures != 0) {
        const to: u6 = @intCast(bit.leastSignificantBit(captures));
        bit.popBit(&captures, to);

        const target_bb = @as(u64, 1) << to;
        const is_left = (left & target_bb) != 0;

        const from = if (side == 0)
            if (is_left) to - 7 else to - 9
        else
            if (is_left) to + 9 else to + 7;

        if (to != ep_sq and (their_pieces & target_bb) == 0) continue;
        if (pin_masks[from] != 0 and (pin_masks[from] & target_bb) == 0)
            continue;

        if (to == ep_sq) {
            var bcopy = board.*;
            bcopy.updateBoard(piece, from, to, side, true);
            if (bcopy.isSquareAttacked(king_sq, side) != 0) continue;

            try list.append(.{
                .source = from,
                .target = to,
                .piece = piece,
                .isCapture = true,
                .isEnPassant = true,
            });
        } else {
            const is_promo = (target_bb & rank7) != 0;
            if (is_promo) {
                try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .Q, .isCapture = true });
                try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .R, .isCapture = true });
                try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .B, .isCapture = true });
                try list.append(.{ .source = from, .target = to, .piece = piece, .promotion = .N, .isCapture = true });
            } else {
                try list.append(.{ .source = from, .target = to, .piece = piece, .isCapture = true });
            }
        }
    }
}



pub inline fn pieceMoves() !void {
    var pieces = if (side == 0) board.wPieces() else board.bPieces();
    const opponent_pieces = if (side == 0) board.bPieces() else board.wPieces();
    // const king_square: u6 = @intCast(bit.leastSignificantBit(
    //     if (side == 0) board.wKing else board.bKing
    // ));
    pieces &= ~(board.bPawns | board.wPawns);

    for (0..64) |source_u6| {
        const source: u6 = @intCast(source_u6);

        const source_board = @as(u64, 1) << source;
        if ((pieces & source_board) == 0) continue;

        const piece = board.GetPieceAtSquare(source);
        if (piece == null) continue;
        if (piece.? == .P or piece == .p or piece.? == .K or piece.? == .k ) continue;

        var targets = board.getPieceAttacks(piece.?, source, side);
        if (captures_only) targets &= opponent_pieces;

        if (check_mask > 0 and piece.? != .K and piece.? != .k) {
            targets &= check_mask;
        }

        const pin_mask_piece = pin_masks[source];
        if (pin_mask_piece != 0 and piece.? != .K and piece.? != .k) {
            targets &= pin_mask_piece;
        }

        while (targets > 0) {
            const target: u6 = @intCast(bit.leastSignificantBit(targets));
            bit.popBit(&targets, target);
            const target_board = @as(u64, 1) << target;

            if ((piece.? == .K or piece.? == .k) and board.isSquareAttacked(target, side) > 0) {
                continue;
            }
            if ((piece.? != .K and piece.? != .k) and pin_mask_piece != 0 and (pin_mask_piece & target_board) == 0) {
                continue;
            }

            const is_capture = (target_board & opponent_pieces) > 0;
            try list.append(Move{
                .source = source,
                .target = target,
                .piece = piece.?,
                .isCapture = is_capture
            });
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

    const CastleParams = struct {
        king_sq: u6,
        rights: u4,
        rook_mask: u64,
        w_rook_squares: struct { kingside: u6, queenside: u6 },
        f_sq: u6, g_sq: u6, d_sq: u6, c_sq: u6, b_sq: u6,
    };

    const params: CastleParams = if (side == 0)
        .{
            .king_sq = 60,
            .rights = board.castle & 0b0011,
            .rook_mask = board.wRooks,
            .w_rook_squares = .{ .kingside = 63, .queenside = 56 },
            .f_sq = 61, .g_sq = 62, .d_sq = 59, .c_sq = 58, .b_sq = 57,
        }
    else
        .{
            .king_sq = 4,
            .rights = (board.castle & 0b1100) >> 2,
            .rook_mask = board.bRooks,
            .w_rook_squares = .{ .kingside = 7, .queenside = 0 },
            .f_sq = 5, .g_sq = 6, .d_sq = 3, .c_sq = 2, .b_sq = 1,
        };

    if (bit.getBit(board.allPieces(), params.king_sq) == 0) return;

    const occupied = board.allPieces();

    // Kingside castle
    if ((params.rights & 0b01) != 0 and bit.getBit(params.rook_mask, params.w_rook_squares.kingside) != 0) {
        if (!(bit.getBit(occupied, params.f_sq) > 0) and
            !(bit.getBit(occupied, params.g_sq) > 0) and
            !(board.isSquareAttacked(params.king_sq, side) > 0) and
            !(board.isSquareAttacked(params.f_sq, side) > 0) and
            !(board.isSquareAttacked(params.g_sq, side) > 0))
        {
            try list.append(Move{
                .source = params.king_sq,
                .target = params.g_sq,
                .piece = piece,
                .castle = if (side == 0) .WK else .BK,
            });
        }
    }

    // Queenside castle
    if ((params.rights & 0b10) != 0 and bit.getBit(params.rook_mask, params.w_rook_squares.queenside) != 0) {
        if (!(bit.getBit(occupied, params.d_sq) > 0) and
            !(bit.getBit(occupied, params.c_sq) > 0) and
            !(bit.getBit(occupied, params.b_sq) > 0) and
            !(board.isSquareAttacked(params.king_sq, side) > 0) and
            !(board.isSquareAttacked(params.d_sq, side) > 0) and
            !(board.isSquareAttacked(params.c_sq, side) > 0))
        {
            try list.append(Move{
                .source = params.king_sq,
                .target = params.c_sq,
                .piece = piece,
                .castle = if (side == 0) .WQ else .BQ,
            });
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
    const ep_square = @ctz(board.enPassantSquare);
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
    const king_square = if (side == 0) @ctz(board.wKing) else @ctz(board.bKing);
    if (board.isSquareAttacked(@intCast(king_square), side) > 0) {
        return false;
    }
    board.sideToMove = ~side;
    zob.generateHashKey(board);

    return true;
}
