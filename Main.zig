const std = @import("std");
const map = @import("Maps/Maps.zig");
const bit = @import("BitManipulation/BitManipulation.zig");
const sqr = @import("Board/Square.zig");
const rand = @import("Random/Rand.zig");
const board = @import("Game/Board.zig");
const fen = @import("Testing/FenStrings.zig");
const mv = @import("Moves/Moves.zig");

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn().reader();

pub fn main() !void {
    try map.InitializeAttackTables();

    var occ: u64 = 0;
    bit.SetBit(&occ, .C5);
    bit.SetBit(&occ, .F2);
    bit.SetBit(&occ, .G7);
    bit.SetBit(&occ, .B2);
    bit.SetBit(&occ, .G5);
    bit.SetBit(&occ, .E2);
    bit.SetBit(&occ, .E7);
    try bit.Print(occ);
    try bit.Print(map.GetBishopAttacks(sqr.Square.toIndex(.D4), occ));
    try printMoves();

    const mn = rand.FindMagicNumber(0, map.bishopRelevantBits[0], true);
    try stdout.print("{}", .{mn});
}

pub fn printMoves() !void {
    var brd = board.emptyBoard();
    board.setBoardFromFEN(fen.tricky_position_with_promotion, &brd);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var list = std.ArrayList(mv.Move).init(allocator);
    defer list.deinit();

    try mv.GenerateMoves(&list, &brd, 0);

    for (0..list.items.len) |index| {
        var move = list.items[index];
        const start = try sqr.Square.fromIndex(move.source);
        const end = try sqr.Square.fromIndex(move.target);
        if (move.isPromotion()) {
            const promo: mv.Promotion = @enumFromInt(move.promotion);
            try stdout.print("{s} {s} Promotion: {}\n", .{ start.toString(), end.toString(), promo });
        } else {
            try stdout.print("{s} {s}\n", .{ start.toString(), end.toString() });
        }
    }
}
pub fn printTestBoards() !void {
    var bitbrd: board.Board = board.emptyBoard();
    try bit.Print(bitbrd.wKing);
    board.setBoardFromFEN(fen.tricky_position_with_promotion, &bitbrd);

    try stdout.print("\nWhite Pawns: \n", .{});
    try bit.Print(bitbrd.wPawns);
    try stdout.print("\nWhite Knights: \n", .{});
    try bit.Print(bitbrd.wKnights);
    try stdout.print("\nWhite Bishops: \n", .{});
    try bit.Print(bitbrd.wBishops);
    try stdout.print("\nWhite Rooks: \n", .{});
    try bit.Print(bitbrd.wRooks);
    try stdout.print("\nWhite Queens: \n", .{});
    try bit.Print(bitbrd.wQueens);
    try stdout.print("\nWhite Kings: \n", .{});
    try bit.Print(bitbrd.wKing);
    try stdout.print("\nWhite Pieces: \n", .{});
    try bit.Print(bitbrd.wPieces);
    try stdout.print("\nBlack Pawns: \n", .{});
    try bit.Print(bitbrd.bPawns);
    try stdout.print("\nBlack Knights: \n", .{});
    try bit.Print(bitbrd.bKnights);
    try stdout.print("\nBlack Bishops: \n", .{});
    try bit.Print(bitbrd.bBishops);
    try stdout.print("\nBlack Rooks: \n", .{});
    try bit.Print(bitbrd.bRooks);
    try stdout.print("\nBlack Queens: \n", .{});
    try bit.Print(bitbrd.bQueens);
    try stdout.print("\nBlack Kings: \n", .{});
    try bit.Print(bitbrd.bKing);
    try stdout.print("\nBlack Pieces: \n", .{});
    try bit.Print(bitbrd.bPieces);
    try stdout.print("\nAll Pieces: \n", .{});
    try bit.Print(bitbrd.bPieces);
    try stdout.print("\nEn Passant Square: \n", .{});
    try bit.Print(bitbrd.enPassantSquare);

    try stdout.print("\nCastling Rights: {d} \n", .{bitbrd.castle});

    const s = sqr.Square.toIndex(.G5);
    const attacked = bitbrd.isSquareAttacked(s, 1);
    try stdout.print("Square attacked: {}", .{attacked});
}
