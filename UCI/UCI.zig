const std = @import("std");
const mv = @import("../Moves/Moves.zig");
const brd = @import("../Board/Board.zig");
const bit = @import("../BitManipulation/BitManipulation.zig");

fn charToFile(c: u8) u6 {
    return @intCast(c - 'a');
}

fn charToRank(c: u8) u6 {
    return @intCast(7 - (c - '1'));
}

fn squareFromNotation(file: u8, rank: u8) u6 {
    return @intCast(rank * 8 + file);
}

pub fn parseMove(notation: []const u8, board: brd.Board) ?mv.Move {
    if (notation.len < 4 or notation.len > 5) {
        return null;
    }

    const from_file = charToFile(notation[0]);
    const from_rank = charToRank(notation[1]);
    const to_file = charToFile(notation[2]);
    const to_rank = charToRank(notation[3]);

    std.debug.print("\n{}{}{}{}\n", .{ from_file, from_rank, to_file, to_rank });

    if (from_file >= 8 or from_rank >= 8 or to_file >= 8 or to_rank >= 8) {
        return null;
    }

    const from_square = squareFromNotation(from_file, from_rank);
    const to_square = squareFromNotation(to_file, to_rank);
    std.debug.print("\n{} {}\n", .{ from_square, to_square });
    var promotion: mv.Promotion = .X;

    if (notation.len == 5) {
        const promo_piece = notation[4];
        if (promo_piece == 'q' or promo_piece == 'r' or promo_piece == 'b' or promo_piece == 'n') {
            switch (promo_piece) {
                'N', 'n' => {
                    promotion = .N;
                },
                'B', 'b' => {
                    promotion = .B;
                },
                'R', 'r' => {
                    promotion = .R;
                },
                'Q', 'q' => {
                    promotion = .Q;
                },
                else => {
                    promotion = .X;
                },
            }
        }
    }
    const pieceBoard = @as(u64, 1) << from_square;
    var piece: brd.Pieces = undefined;
    if ((board.wPawns & pieceBoard) > 0) piece = .P;
    if ((board.wKnights & pieceBoard) > 0) piece = .N;
    if ((board.wBishops & pieceBoard) > 0) piece = .B;
    if ((board.wRooks & pieceBoard) > 0) piece = .R;
    if ((board.wQueens & pieceBoard) > 0) piece = .Q;
    if ((board.wKing & pieceBoard) > 0) piece = .K;
    if ((board.bPawns & pieceBoard) > 0) piece = .p;
    if ((board.bKnights & pieceBoard) > 0) piece = .n;
    if ((board.bBishops & pieceBoard) > 0) piece = .b;
    if ((board.bRooks & pieceBoard) > 0) piece = .r;
    if ((board.bQueens & pieceBoard) > 0) piece = .q;
    if ((board.bKing & pieceBoard) > 0) piece = .k;

    return mv.Move{
        .source = from_square,
        .target = to_square,
        .promotion = promotion,
        .piece = piece,
    };
}
