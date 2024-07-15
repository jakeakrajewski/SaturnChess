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
    try map.InitializeAttackTables();
    try UCILoop();
}

pub fn UCILoop() !void {
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
                try uci.Go(&board, input);
            } else if (std.mem.eql(u8, command, "position")) {
                try uci.Position(&board, input);
            } else if (std.mem.eql(u8, input, "isready")) {
                try std.io.getStdOut().writer().print("readyok\n", .{});
            } else if (std.mem.eql(u8, input, "ucinewgame")) {
                try uci.Position(&board, "position startpos");
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
    bit.Print(bitboard.wPawns);
    std.debug.print("\nWhite Knights: \n", .{});
    bit.Print(bitboard.wKnights);
    std.debug.print("\nWhite Bishops: \n", .{});
    bit.Print(bitboard.wBishops);
    std.debug.print("\nWhite Rooks: \n", .{});
    bit.Print(bitboard.wRooks);
    std.debug.print("\nWhite Queens: \n", .{});
    bit.Print(bitboard.wQueens);
    std.debug.print("\nWhite Kings: \n", .{});
    bit.Print(bitboard.wKing);
    std.debug.print("\nWhite Pieces: \n", .{});
    bit.Print(bitboard.wPieces());
    std.debug.print("\nBlack Pawns: \n", .{});
    bit.Print(bitboard.bPawns);
    std.debug.print("\nBlack Knights: \n", .{});
    bit.Print(bitboard.bKnights);
    std.debug.print("\nBlack Bishops: \n", .{});
    bit.Print(bitboard.bBishops);
    std.debug.print("\nBlack Rooks: \n", .{});
    bit.Print(bitboard.bRooks);
    std.debug.print("\nBlack Queens: \n", .{});
    bit.Print(bitboard.bQueens);
    std.debug.print("\nBlack Kings: \n", .{});
    bit.Print(bitboard.bKing);
    std.debug.print("\nBlack Pieces: \n", .{});
    bit.Print(bitboard.bPieces());
    std.debug.print("\nAll Pieces: \n", .{});
    bit.Print(bitboard.allPieces());
    std.debug.print("\nEn Passant Square: \n", .{});
    bit.Print(bitboard.enPassantSquare);

    std.debug.print("\nCastling Rights: {d} \n", .{bitboard.castle});

    const s = sqr.Square.toIndex(.D3);
    const attacked = bitboard.isSquareAttacked(s, 1);
    std.debug.print("Square attacked: {}", .{attacked});
}
