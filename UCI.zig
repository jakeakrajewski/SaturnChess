const std = @import("std");
const sqr = @import("Square.zig");
const mv = @import("Moves.zig");
const brd = @import("Board.zig");
const bit = @import("BitManipulation.zig");
const fen = @import("FenStrings.zig");
const perft = @import("Perft.zig");
const search = @import("Search.zig");
const builtin = @import("builtin");

var depth: u8 = 64;
var white_time: i64 = 0;
var black_time: i64 = 0;
var white_increment: i64 = 0;
var black_increment: i64 = 0;
var timed_search: bool = true;
var time_allowance: i64 = -1;
var moves_to_go: i16 = -1;

pub fn uciLoop() !void {
    try std.io.getStdOut().writer().print("id name Saturn\n", .{});
    try std.io.getStdOut().writer().print("id name Jake Krajewski\n", .{});
    try std.io.getStdOut().writer().print("uciok\n", .{});
    const allocator = std.heap.page_allocator;

    var board: brd.Board = undefined;
    brd.setBoardFromFEN(fen.start_position, &board);
    var buffer = try allocator.alloc(u8, 2048);

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
                try go(&board, input);
            } else if (std.mem.eql(u8, command, "position")) {
                try position(&board, input);
            } else if (std.mem.eql(u8, input, "isready")) {
                try std.io.getStdOut().writer().print("readyok\n", .{});
            } else if (std.mem.eql(u8, input, "ucinewgame")) {
                try position(&board, "position startpos");
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

    if (from_file >= 8 or from_rank >= 8 or to_file >= 8 or to_rank >= 8) {
        return null;
    }

    const from_square = squareFromNotation(from_file, from_rank);
    const to_square = squareFromNotation(to_file, to_rank);
    var promotion: mv.Promotion = .X;

    if (notation.len == 5) {
        const promo_piece = notation[4];
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
    const piece_board = @as(u64, 1) << from_square;
    var piece: brd.Pieces = undefined;
    if ((board.wPawns & piece_board) > 0) piece = .P;
    if ((board.wKnights & piece_board) > 0) piece = .N;
    if ((board.wBishops & piece_board) > 0) piece = .B;
    if ((board.wRooks & piece_board) > 0) piece = .R;
    if ((board.wQueens & piece_board) > 0) piece = .Q;
    if ((board.wKing & piece_board) > 0) piece = .K;
    if ((board.bPawns & piece_board) > 0) piece = .p;
    if ((board.bKnights & piece_board) > 0) piece = .n;
    if ((board.bBishops & piece_board) > 0) piece = .b;
    if ((board.bRooks & piece_board) > 0) piece = .r;
    if ((board.bQueens & piece_board) > 0) piece = .q;
    if ((board.bKing & piece_board) > 0) piece = .k;

    var castles: brd.Castle = .N;
    if (piece == .K and from_square == 60 and to_square == 62) castles = .WK;
    if (piece == .K and from_square == 60 and to_square == 58) castles = .WQ;
    if (piece == .k and from_square == 4 and to_square == 6) castles = .BK;
    if (piece == .k and from_square == 4 and to_square == 2) castles = .BQ;

    var is_double = false;
    if (piece == .P or piece == .p) {
        const to: i16 = @intCast(to_square);
        const from: i16 = @intCast(from_square);
        if (@abs(to - from) == 16) {
            is_double = true;
        }
    }
    const ep = if (to_square == bit.leastSignificantBit(board.enPassantSquare)) true else false;

    return mv.Move{
        .source = from_square,
        .target = to_square,
        .promotion = promotion,
        .piece = piece,
        .castle = castles,
        .isDoublePush = is_double,
        .isEnPassant = ep,
    };
}

pub fn position(board: *brd.Board, tokens: []const u8) !void {
    var split = std.mem.split(u8, tokens, " ");
    const command = split.next().?;

    if (!std.mem.eql(u8, command, "position")) {
        @panic("Invalid command passed to position.");
    }

    const command2 = split.next();
    if (command2 == null) return;

    if (std.mem.eql(u8, command2.?, "startpos")) {
        brd.setBoardFromFEN(fen.start_position, board);

        var still_moves = true;

        const command3 = split.next();
        if (command3 == null) return;
        if (std.mem.eql(u8, command3.?, "moves")) {
            while (still_moves) {
                const move = split.next();
                if (move) |m| {
                    const parsed_move = parseMove(m, board.*);
                    if (parsed_move) |pm| {
                        const result = mv.makeMove(pm, board, board.sideToMove);
                        if (!result) {
                            @panic("Invalid move received in position command");
                        }
                    }
                } else {
                    still_moves = false;
                }
            }
        }
    } else if (std.mem.eql(u8, command2.?, "fen")) {
        const pos = split.next().?;
        const side = split.next().?;
        const castles = split.next().?;
        const ep = split.next().?;
        const majorClock = split.next().?;
        const minorClock = split.next().?;
        const fenLength: usize = pos.len + side.len + castles.len + ep.len + majorClock.len + minorClock.len + 6;
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var allocator = arena.allocator();
        const buffer = try allocator.alloc(u8, fenLength);
        defer allocator.free(buffer);

        const fenString = try std.fmt.bufPrint(buffer, "{s} {s} {s} {s} {s} {s}", .{ pos, side, castles, ep, majorClock, minorClock });
        brd.setBoardFromFEN(fenString, board);

        var still_moves = true;

        const command3 = split.next();
        if (command3 == null) return;
        if (std.mem.eql(u8, command3.?, "moves")) {
            while (still_moves) {
                const move = split.next();
                if (move) |m| {
                    const parsed_move = parseMove(m, board.*);
                    if (parsed_move) |pm| {
                        const result = mv.makeMove(pm, board, board.sideToMove);
                        if (!result) {
                            @panic("Invalid move received in position command");
                        }
                    }
                } else {
                    still_moves = false;
                }
            }
        }
    }
}

pub fn go(board: *brd.Board, tokens: []const u8) !void {
    var split = std.mem.split(u8, tokens, " ");
    const command = split.first();

    if (!std.mem.eql(u8, command, "go")) {
        @panic("Invalid command passed to go.");
    }

    var next_string = split.next();
    if (next_string == null) return;

    while (next_string != null) {
        if (std.mem.eql(u8, next_string.?, "perft")) {
            const depth_str = split.next();
            if (depth_str) |d| {
                depth = try std.fmt.parseInt(u8, d, 10);
                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                const allocator = arena.allocator();
                var list = std.ArrayList(mv.Move).init(allocator);
                defer list.deinit();
                const start_time = std.time.milliTimestamp();
                const pos = try perft.perft(board, &list, depth, depth, board.sideToMove, allocator);
                const end_time = std.time.milliTimestamp();
                const diff: u64 = @intCast(end_time - start_time);
                try std.io.getStdOut().writer().print("\nMoves: {}", .{pos.Nodes});
                try std.io.getStdOut().writer().print("\nCaptures: {}", .{pos.Captures});
                try std.io.getStdOut().writer().print("\nEnPassant: {}", .{pos.EnPassant});
                try std.io.getStdOut().writer().print("\nPromotions: {}", .{pos.Promotions});
                try std.io.getStdOut().writer().print("\nCastles: {}", .{pos.Castles});
                try std.io.getStdOut().writer().print("\nElapsed Time: {} ms \n\n", .{diff});
            }
            return;
        }
        if (std.mem.eql(u8, next_string.?, "depth")) {
            next_string = split.next();
            timed_search = false;
            if (next_string == null) break;
            if (next_string) |d| {
                depth = try std.fmt.parseInt(u8, d, 10);
            }
        }
        if (std.mem.eql(u8, next_string.?, "wtime")) {
            timed_search = true;
            next_string = split.next();
            if (next_string == null) break;
            if (next_string) |time| {
                white_time = try std.fmt.parseInt(i64, time, 10);
            }
        }

        if (std.mem.eql(u8, next_string.?, "btime")) {
            next_string = split.next();
            if (next_string == null) break;
            if (next_string) |time| {
                black_time = try std.fmt.parseInt(i64, time, 10);
            }
        }
        if (std.mem.eql(u8, next_string.?, "winc")) {
            next_string = split.next();
            if (next_string == null) break;
            if (next_string) |num| {
                white_increment = try std.fmt.parseInt(i64, num, 10);
            }
        }
        if (std.mem.eql(u8, next_string.?, "binc")) {
            next_string = split.next();
            if (next_string == null) break;
            if (next_string) |num| {
                black_increment = try std.fmt.parseInt(i64, num, 10);
            }
        }
        if (std.mem.eql(u8, next_string.?, "movestogo")) {
            next_string = split.next();
            if (next_string == null) break;
            if (next_string) |num| {
                moves_to_go = try std.fmt.parseInt(i16, num, 10);
            }
        }
        next_string = split.next();
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var list = std.ArrayList(mv.Move).init(allocator);
    defer list.deinit();
    const remaining_time = if (board.sideToMove == 0) white_time else black_time;
    const increment = if (board.sideToMove == 0) white_increment else black_increment;
    if (timed_search) {
        if (moves_to_go > -1) {
            time_allowance = @intCast(@divTrunc(remaining_time, moves_to_go) + @divTrunc(increment, 2));
        } else {
            time_allowance = @intCast(@divTrunc(remaining_time, 30) + @divTrunc(increment, 2));
        }
        if (time_allowance > remaining_time) time_allowance = remaining_time - 500;
        if (time_allowance < 0) time_allowance = 100;
        std.debug.print("\nTime Allowance: {}\n", .{time_allowance});
    } else {
        time_allowance = -1;
    }
    const start_time = std.time.milliTimestamp();
    const best_move = try search.Search(board, &list, depth, timed_search, time_allowance);
    const end_time = std.time.milliTimestamp();
    std.debug.print("\nTotal Search Time: {}ms\n", .{end_time - start_time});
    const start = try sqr.Square.FromIndex(best_move.source);
    const target = try sqr.Square.FromIndex(best_move.target);
    var promo: []const u8 = undefined;
    if (best_move.promotion != .X) {
        switch (best_move.promotion) {
            .N => {
                promo = if (board.sideToMove == 0) "N" else "n";
            },
            .B => {
                promo = if (board.sideToMove == 0) "B" else "b";
            },
            .R => {
                promo = if (board.sideToMove == 0) "R" else "r";
            },
            .Q => {
                promo = if (board.sideToMove == 0) "Q" else "q";
            },
            else => {
                promo = "";
            },
        }
        try std.io.getStdOut().writer().print("bestmove {s}{s}{s}\n", .{ start.toString(), target.toString(), promo });
    } else {
        try std.io.getStdOut().writer().print("bestmove {s}{s}\n", .{ start.toString(), target.toString() });
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
