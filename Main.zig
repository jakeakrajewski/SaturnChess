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
    // try printMoves();
    // printTestBoards();
    // IsKingAttacked();
    // TestAttackTables();
}

pub fn RunPerft() !void {
    var brd: board.Board = undefined;
    board.setBoardFromFEN(fen.start_position, &brd);
    const depth: u8 = 6;
    const startTime = std.time.milliTimestamp();
    const pos = try perft.Perft(&brd, depth, 0);
    const endTime = std.time.milliTimestamp();
    const diff: u64 = @intCast(endTime - startTime);
    std.debug.print("\nMoves: {}", .{pos.Nodes});
    std.debug.print("\nCaptures: {}", .{pos.Captures});
    std.debug.print("\nEnPassant: {}", .{pos.EnPassant});
    std.debug.print("\nPromotions: {}", .{pos.Promotions});
    std.debug.print("\nCastles: {}", .{pos.Castles});
    std.debug.print("\nElapsed Time: {} ms", .{diff});
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
            std.debug.print("{s} {s} {}", .{ start.toString(), end.toString(), move.isEnPassant });
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

pub fn printTestBoards() void {
    var bitbrd: board.Board = board.emptyBoard();
    bit.Print(bitbrd.wKing);
    board.setBoardFromFEN(fen.checkWithBlocker, &bitbrd);

    std.debug.print("\nWhite Pawns: \n", .{});
    bit.Print(bitbrd.wPawns);
    std.debug.print("\nWhite Knights: \n", .{});
    bit.Print(bitbrd.wKnights);
    std.debug.print("\nWhite Bishops: \n", .{});
    bit.Print(bitbrd.wBishops);
    std.debug.print("\nWhite Rooks: \n", .{});
    bit.Print(bitbrd.wRooks);
    std.debug.print("\nWhite Queens: \n", .{});
    bit.Print(bitbrd.wQueens);
    std.debug.print("\nWhite Kings: \n", .{});
    bit.Print(bitbrd.wKing);
    std.debug.print("\nWhite Pieces: \n", .{});
    bit.Print(bitbrd.wPieces());
    std.debug.print("\nBlack Pawns: \n", .{});
    bit.Print(bitbrd.bPawns);
    std.debug.print("\nBlack Knights: \n", .{});
    bit.Print(bitbrd.bKnights);
    std.debug.print("\nBlack Bishops: \n", .{});
    bit.Print(bitbrd.bBishops);
    std.debug.print("\nBlack Rooks: \n", .{});
    bit.Print(bitbrd.bRooks);
    std.debug.print("\nBlack Queens: \n", .{});
    bit.Print(bitbrd.bQueens);
    std.debug.print("\nBlack Kings: \n", .{});
    bit.Print(bitbrd.bKing);
    std.debug.print("\nBlack Pieces: \n", .{});
    bit.Print(bitbrd.bPieces());
    std.debug.print("\nAll Pieces: \n", .{});
    bit.Print(bitbrd.allPieces());
    std.debug.print("\nEn Passant Square: \n", .{});
    bit.Print(bitbrd.enPassantSquare);

    std.debug.print("\nCastling Rights: {d} \n", .{bitbrd.castle});

    const s = sqr.Square.toIndex(.D3);
    const attacked = bitbrd.isSquareAttacked(s, 1);
    std.debug.print("Square attacked: {}", .{attacked});
}

pub fn IsKingAttacked() void {
    var brd: board.Board = undefined;
    board.setBoardFromFEN(fen.checkWithBlocker, &brd);
    const kingSquare = bit.LeastSignificantBit(brd.wKing);
    std.debug.print("King Square: {any}\n", .{sqr.Square.fromIndex(@intCast(kingSquare))});
    if (brd.isSquareAttacked(@intCast(kingSquare), 0)) {
        std.debug.print("true", .{});
    } else {
        std.debug.print("false", .{});
    }
}

pub fn TestAttackTables() void {
    var brd: board.Board = undefined;
    board.setBoardFromFEN(fen.checkWithBlocker, &brd);
    const kingSquare = bit.LeastSignificantBit(brd.wKing);
    bit.Print(map.GetRookAttacks(@intCast(kingSquare), brd.allPieces()));
}
