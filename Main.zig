const std = @import("std");
const map = @import("Maps/Maps.zig");
const bit = @import("BitManipulation/BitManipulation.zig");
const sqr = @import("Board/Square.zig");
const rand = @import("Random/Rand.zig");
const brd = @import("Board/Board.zig");
const fen = @import("Testing/FenStrings.zig");
const mv = @import("Moves/Moves.zig");
const perft = @import("Perft/Perft.zig");
const uci = @import("UCI/UCI.zig");

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn().reader();

pub fn main() !void {
    try map.InitializeAttackTables();
    // const depth: u8 = 6;
    // const side: u1 = 0;
    const position: []const u8 = fen.start_position;
    // try RunPerft(position, depth);
    // try printMoves(position, side);
    ParseMoveTest(position);
    // TestCastlingRights();
    // printTestBoards();
    // IsKingAttacked();
    // TestAttackTables();
    // CheckPin();
}
pub fn ParseMoveTest(position: []const u8) void {
    var board: brd.Board = undefined;
    brd.setBoardFromFEN(position, &board);
    bit.Print(board.allPieces());
    const move = uci.parseMove("b1c3", board);
    if (move) |m| {
        var start = try sqr.Square.fromIndex(m.source);
        var end = try sqr.Square.fromIndex(m.target);
        std.debug.print("Start Square: {s}\n", .{start.toString()});
        std.debug.print("End Square: {s}\n", .{end.toString()});
        std.debug.print("Piece: {}\n", .{m.piece});
        const result = mv.MakeMove(m, &board, 0);
        if (result) bit.Print(board.allPieces());
    }
}
pub fn CheckPin(position: []const u8, side: u1) void {
    var board: brd.Board = undefined;
    brd.setBoardFromFEN(position, &board);
    bit.Print(board.allPieces());
    bit.Print(mv.GetPinMask(board, side));
    bit.Print(mv.GetCheckMask(board, side));
}

pub fn RunPerft(position: []const u8, depth: u8) !void {
    var board: brd.Board = undefined;
    brd.setBoardFromFEN(position, &board);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var moves = std.ArrayList(mv.Move).init(allocator);
    defer moves.deinit();
    const startTime = std.time.milliTimestamp();
    const pos = try perft.Perft(&board, moves, depth, depth, board.sideToMove, allocator);
    const endTime = std.time.milliTimestamp();
    const diff: u64 = @intCast(endTime - startTime);
    std.debug.print("\nMoves: {}", .{pos.Nodes});
    std.debug.print("\nCaptures: {}", .{pos.Captures});
    std.debug.print("\nEnPassant: {}", .{pos.EnPassant});
    std.debug.print("\nPromotions: {}", .{pos.Promotions});
    std.debug.print("\nCastles: {}", .{pos.Castles});
    std.debug.print("\nElapsed Time: {} ms", .{diff});
    std.debug.print("\nMove Generationg Time: {} ms", .{pos.GenerationTime});
    std.debug.print("\nMake Move Time: {} ms", .{pos.MakeTime});
}

pub fn printMoves(position: []const u8, side: u1) !void {
    var board = brd.emptyBoard();
    brd.setBoardFromFEN(position, &board);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var list = std.ArrayList(mv.Move).init(allocator);
    defer list.deinit();

    try mv.GenerateMoves(&list, &board, side);

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
    var board = brd.emptyBoard();
    brd.setBoardFromFEN(fen.doubleEnPassant, &board);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var list = std.ArrayList(mv.Move).init(allocator);
    defer list.deinit();
    try mv.GenerateMoves(&list, &board, 0);
    var boardCopy = brd;
    std.debug.print("Castle Rights: {d}", .{boardCopy.castle});
    bit.Print(boardCopy.allPieces());
    const move = list.items[1];
    var start = try sqr.Square.fromIndex(move.source);
    var end = try sqr.Square.fromIndex(move.target);
    std.debug.print("{s} {s}", .{ start.toString(), end.toString() });
    const result = mv.MakeMove(move, &boardCopy, 0);
    if (result) {
        bit.Print(boardCopy.allPieces());
        std.debug.print("Castle Rights: {d}", .{boardCopy.castle});
    } else {
        std.debug.print("king in check", .{});
    }
}

pub fn printTestBoards() void {
    var bitboard: brd.Board = brd.emptyBoard();
    bit.Print(bitboard.wKing);
    brd.setBoardFromFEN(fen.doubleEnPassant, &bitboard);

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
pub fn TestCastlingRights() void {
    var board: brd.Board = undefined;
    brd.setBoardFromFEN(fen.castleTest, &board);
    const bqr = sqr.Square.toIndex(.A8);
    const a7 = sqr.Square.toIndex(.A7);
    const bkr = sqr.Square.toIndex(.H8);
    const h7 = sqr.Square.toIndex(.H7);
    const wkr = sqr.Square.toIndex(.H1);
    // const a2 = sqr.Square.toIndex(.A2);
    const wqr = sqr.Square.toIndex(.A1);
    const h2 = sqr.Square.toIndex(.H2);
    std.debug.print("{} \n", .{board.castle});

    // White King Side Rook Move
    const whiteKingRook: mv.Move = mv.Move{ .source = wkr, .target = h2, .piece = board.Pieces.R };
    var result = mv.MakeMove(whiteKingRook, &board, 0);
    if (result) bit.Print(board.allPieces());
    std.debug.print("\n White King Rook Move: {} \n", .{board.castle});
    brd.setBoardFromFEN(fen.castleTest, &board);

    // White Queen Side Rook Move
    const whiteQueenRook: mv.Move = mv.Move{ .source = wqr, .target = bqr, .piece = board.Pieces.R };
    result = mv.MakeMove(whiteQueenRook, &board, 0);
    bit.Print(board.allPieces());
    std.debug.print("\n White Queen Rook Move: {} \n", .{board.castle});
    brd.setBoardFromFEN(fen.castleTest, &board);

    // White King Side Rook Move
    const blackKingRook: mv.Move = mv.Move{ .source = bkr, .target = h7, .piece = board.Pieces.r };
    result = mv.MakeMove(blackKingRook, &board, 1);
    bit.Print(board.allPieces());
    std.debug.print("\n Black King Rook Move: {} \n", .{board.castle});
    brd.setBoardFromFEN(fen.castleTest, &board);

    // White King Side Rook Move
    const blackQueenRook: mv.Move = mv.Move{ .source = bqr, .target = a7, .piece = board.Pieces.r };
    result = mv.MakeMove(blackQueenRook, &board, 1);
    bit.Print(board.allPieces());
    std.debug.print("\n Black Queen Rook Move: {} \n", .{board.castle});
}

pub fn IsKingAttacked() void {
    var board: brd.Board = undefined;
    brd.setBoardFromFEN(fen.checkWithBlocker, &board);
    const kingSquare = bit.LeastSignificantBit(board.wKing);
    std.debug.print("King Square: {any}\n", .{sqr.Square.fromIndex(@intCast(kingSquare))});
    if (board.isSquareAttacked(@intCast(kingSquare), 0)) {
        std.debug.print("true", .{});
    } else {
        std.debug.print("false", .{});
    }
}

pub fn TestAttackTables() void {
    var board: brd.Board = undefined;
    brd.setBoardFromFEN(fen.checkWithBlocker, &board);
    const kingSquare = bit.LeastSignificantBit(board.wKing);
    bit.Print(map.GetRookAttacks(@intCast(kingSquare), board.allPieces()));
}
