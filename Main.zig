const std = @import("std");
const map = @import("Maps.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const rand = @import("Rand.zig");
const brd = @import("Board.zig");
const fen = @import("FenStrings.zig");
const mv = @import("Moves.zig");
const perft = @import("Perft.zig");
const uci = @import("UCI.zig");
const eval = @import("Evaluate.zig");
const builtin = @import("builtin");

pub fn main() !void {
    try map.initializeAttackTables();
    try uciLoop();
}

pub fn uciLoop() !void {
    try std.io.getStdOut().writer().print("id name Saturn\n", .{});
    try std.io.getStdOut().writer().print("id name Jake Krajewski\n", .{});
    try std.io.getStdOut().writer().print("uciok\n", .{});
    const allocator = std.heap.page_allocator;

    var board: brd.Board = undefined;
    brd.setBoardFromFEN(fen.start_position, &board);
    var buffer = try allocator.alloc(u8, 1024);

    defer allocator.free(buffer);

    while (true) {
        const input_len = try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer, '\n');

        if (input_len) |l| {
            var input: []const u8 = undefined;
            const target = builtin.target.os.tag;
            if (target == .windows) {
                input = buffer[0 .. l.len - 1];
            } else {
                input = buffer[0..l.len];
            }

            if (std.mem.eql(u8, input, "quit")) {
                break;
            }

            var split = std.mem.split(u8, input, " ");
            const command = split.first();

            if (std.mem.eql(u8, command, "go")) {
                try uci.go(&board, input);
            } else if (std.mem.eql(u8, command, "position")) {
                try uci.position(&board, input);
            } else if (std.mem.eql(u8, input, "isready")) {
                try std.io.getStdOut().writer().print("readyok\n", .{});
            } else if (std.mem.eql(u8, input, "ucinewgame")) {
                try uci.position(&board, "position startpos");
            } else if (std.mem.eql(u8, input, "uci")) {
                try std.io.getStdOut().writer().print("id name Saturn\n", .{});
                try std.io.getStdOut().writer().print("id author Jake Krajewski\n", .{});
                try std.io.getStdOut().writer().print("uciok\n", .{});
            } else if (std.mem.eql(u8, input, "print")) {
                printTestBoards(&board);
            }
        }
    }
}

pub fn printTestBoards(bitboard: *brd.Board) void {
    std.debug.print("\nWhite Pawns: \n", .{});
    bit.print(bitboard.wPawns);
    std.debug.print("\nWhite Knights: \n", .{});
    bit.print(bitboard.wKnights);
    std.debug.print("\nWhite Bishops: \n", .{});
    bit.print(bitboard.wBishops);
    std.debug.print("\nWhite Rooks: \n", .{});
    bit.print(bitboard.wRooks);
    std.debug.print("\nWhite Queens: \n", .{});
    bit.print(bitboard.wQueens);
    std.debug.print("\nWhite Kings: \n", .{});
    bit.print(bitboard.wKing);
    std.debug.print("\nWhite Pieces: \n", .{});
    bit.print(bitboard.wPieces());
    std.debug.print("\nBlack Pawns: \n", .{});
    bit.print(bitboard.bPawns);
    std.debug.print("\nBlack Knights: \n", .{});
    bit.print(bitboard.bKnights);
    std.debug.print("\nBlack Bishops: \n", .{});
    bit.print(bitboard.bBishops);
    std.debug.print("\nBlack Rooks: \n", .{});
    bit.print(bitboard.bRooks);
    std.debug.print("\nBlack Queens: \n", .{});
    bit.print(bitboard.bQueens);
    std.debug.print("\nBlack Kings: \n", .{});
    bit.print(bitboard.bKing);
    std.debug.print("\nBlack Pieces: \n", .{});
    bit.print(bitboard.bPieces());
    std.debug.print("\nAll Pieces: \n", .{});
    bit.print(bitboard.allPieces());
    std.debug.print("\nEn Passant Square: \n", .{});
    bit.print(bitboard.enPassantSquare);

    std.debug.print("\nCastling Rights: {d} \n", .{bitboard.castle});

    const s = sqr.Square.toIndex(.D3);
    const attacked = bitboard.isSquareAttacked(s, 1);
    std.debug.print("Square attacked: {}", .{attacked});
}
