const std = @import("std");
const map = @import("Maps/Maps.zig");
const bit = @import("BitManipulation/BitManipulation.zig");
const sqr = @import("Board/Square.zig");
const rand = @import("Random/Rand.zig");
const board = @import("Board/Board.zig");
const fen = @import("Testing/FenStrings.zig");
const mv = @import("Moves/Moves.zig");
const perft = @import("Perft/Perft.zig");

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn().reader();

pub fn main() !void {
    try map.InitializeAttackTables();
    try RunPerft();
}

pub fn RunPerft() !void {
    var brd: board.Board = undefined;
    board.setBoardFromFEN(fen.tricky_position, &brd);
    const nodes = try perft.Perft(&brd, 2, 0);
    std.debug.print("{} Moves", .{nodes});
}

pub fn printMoves() !void {
    var brd = board.emptyBoard();
    board.setBoardFromFEN(fen.tricky_position, &brd);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var list = std.ArrayList(mv.Move).init(allocator);
    defer list.deinit();

    try mv.GenerateMoves(&list, &brd, 0);

    std.debug.print("Total Moves: {d}\n\n", .{list.items.len});
    for (0..list.items.len) |index| {
        var move = list.items[index];
        var start = try sqr.Square.fromIndex(move.source);
        var end = try sqr.Square.fromIndex(move.target);
        if (move.isPromotion()) {
            const promo = move.promotion;
            std.debug.print("{s} {s} Promotion: {}", .{ start.toString(), end.toString(), promo });
        } else {
            std.debug.print("{s} {s} {}", .{ start.toString(), end.toString(), move.isEnpassant });
        }
        std.debug.print(" Encoded: {}", .{move.Convert()});
        const decoded = mv.fromU24(move.Convert());
        start = try sqr.Square.fromIndex(decoded.source);
        end = try sqr.Square.fromIndex(decoded.target);
        std.debug.print(" Decoded: {s} {s}\n", .{ start.toString(), end.toString() });
    }
}

pub fn makeMoves() !void {
    var brd = board.emptyBoard();
    board.setBoardFromFEN(fen.kinginCheck, &brd);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var list = std.ArrayList(mv.Move).init(allocator);
    defer list.deinit();
    try mv.GenerateMoves(&list, &brd, 0);
    var brdCopy = brd;
    std.debug.print("Castle Rights: {d}", .{brdCopy.castle});
    bit.Print(brdCopy.allPieces());
    const move = list.items[1];
    var start = try sqr.Square.fromIndex(move.source);
    var end = try sqr.Square.fromIndex(move.target);
    std.debug.print("{s} {s}", .{ start.toString(), end.toString() });
    const result = mv.MakeMove(move, &brdCopy, 0);
    if (result) {
        bit.Print(brdCopy.allPieces());
        std.debug.print("Castle Rights: {d}", .{brdCopy.castle});
    } else {
        std.debug.print("king in check", .{});
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
