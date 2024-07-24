const std = @import("std");
const sqr = @import("Square.zig");
const mv = @import("Moves.zig");
const brd = @import("Board.zig");
const bit = @import("BitManipulation.zig");
const fen = @import("FenStrings.zig");
const perft = @import("Perft.zig");
const search = @import("Search.zig");

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

    return mv.Move{
        .source = from_square,
        .target = to_square,
        .promotion = promotion,
        .piece = piece,
        .castle = castles,
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

    const command2 = split.next();
    if (command2 == null) return;

    if (std.mem.eql(u8, command2.?, "perft")) {
        const depth = split.next();
        if (depth) |d| {
            const depth_int = try std.fmt.parseInt(u8, d, 10);
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            const allocator = arena.allocator();
            var list = std.ArrayList(mv.Move).init(allocator);
            defer list.deinit();
            const start_time = std.time.milliTimestamp();
            const pos = try perft.perft(board, list, depth_int, depth_int, board.sideToMove, allocator);
            const end_time = std.time.milliTimestamp();
            const diff: u64 = @intCast(end_time - start_time);
            try std.io.getStdOut().writer().print("\nMoves: {}", .{pos.Nodes});
            try std.io.getStdOut().writer().print("\nCaptures: {}", .{pos.Captures});
            try std.io.getStdOut().writer().print("\nEnPassant: {}", .{pos.EnPassant});
            try std.io.getStdOut().writer().print("\nPromotions: {}", .{pos.Promotions});
            try std.io.getStdOut().writer().print("\nCastles: {}", .{pos.Castles});
            try std.io.getStdOut().writer().print("\nElapsed Time: {} ms \n\n", .{diff});
        }
    } else if (std.mem.eql(u8, command2.?, "depth")) {
        const depth = split.next();
        if (depth) |d| {
            const depth_int = try std.fmt.parseInt(u8, d, 10);
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            const allocator = arena.allocator();
            var list = std.ArrayList(mv.Move).init(allocator);
            defer list.deinit();
            const begin = std.time.milliTimestamp();
            const best_move = try search.Search(board, list, depth_int);
            const end = std.time.milliTimestamp();
            std.debug.print("\nElapsed:{} \n", .{end - begin});
            const start = try sqr.Square.FromIndex(best_move.source);
            const target = try sqr.Square.FromIndex(best_move.target);
            var promo: []const u8 = undefined;
            if (best_move.promotion != .X) {
                switch (best_move.promotion) {
                    .N => {
                        promo = "n";
                    },
                    .B => {
                        promo = "b";
                    },
                    .R => {
                        promo = "r";
                    },
                    .Q => {
                        promo = "q";
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
    } else if (std.mem.eql(u8, command2.?, "wtime")) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const allocator = arena.allocator();
        var list = std.ArrayList(mv.Move).init(allocator);
        defer list.deinit();
        const best_move = try search.Search(board, list, 5);
        const start = try sqr.Square.FromIndex(best_move.source);
        const target = try sqr.Square.FromIndex(best_move.target);
        var promo: u8 = undefined;
        if (best_move.promotion != .X) {
            switch (best_move.promotion) {
                .N => {
                    promo = if (board.sideToMove == 0) 'N' else 'n';
                },
                .B => {
                    promo = if (board.sideToMove == 0) 'B' else 'b';
                },
                .R => {
                    promo = if (board.sideToMove == 0) 'R' else 'r';
                },
                .Q => {
                    promo = if (board.sideToMove == 0) 'Q' else 'q';
                },
                else => {
                    promo = 0;
                },
            }
            try std.io.getStdOut().writer().print("bestmove {s}{s}{}\n", .{ start.toString(), target.toString(), promo });
        } else {
            try std.io.getStdOut().writer().print("bestmove {s}{s}\n", .{ start.toString(), target.toString() });
        }
    }
}
