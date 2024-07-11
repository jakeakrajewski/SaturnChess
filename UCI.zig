const std = @import("std");
const mv = @import("Moves.zig");
const brd = @import("Board.zig");
const bit = @import("BitManipulation.zig");
const fen = @import("FenStrings.zig");
const perft = @import("Perft.zig");

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn();

pub fn UCILoop() !void {
    try stdout.print("id name Saturn\n", .{});
    try stdout.print("id name Jake Krajewski\n", .{});
    try stdout.print("uciok\n", .{});
    const allocator = std.heap.page_allocator;

    var board: brd.Board = undefined;
    brd.setBoardFromFEN(fen.start_position, &board);
    var buffer = try allocator.alloc(u8, 1024);

    defer allocator.free(buffer);

    while (true) {
        const input_len = try stdin.readUntilDelimiterOrEof(buffer, '\n');

        if (input_len) |l| {
            const input = buffer[0..l.len];

            if (std.mem.eql(u8, input, "quit")) {
                break;
            }

            var split = std.mem.split(u8, input, " ");
            const command = split.first();

            if (std.mem.eql(u8, command, "go")) {
                try Go(&board, input);
            } else if (std.mem.eql(u8, command, "position")) {
                try Position(&board, input);
            } else if (std.mem.eql(u8, input, "isready")) {
                try stdout.print("readyok\n", .{});
            } else if (std.mem.eql(u8, input, "ucinewgame")) {
                try Position(&board, "position startpos");
            } else if (std.mem.eql(u8, input, "uci")) {
                try stdout.print("id name Saturn\n", .{});
                try stdout.print("id name Jake Krajewski\n", .{});
                try stdout.print("uciok\n", .{});
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

pub fn Position(board: *brd.Board, tokens: []const u8) !void {
    var split = std.mem.split(u8, tokens, " ");
    const command = split.next().?;

    if (!std.mem.eql(u8, command, "position")) {
        @panic("Invalid command passed to position.");
    }

    const command2 = split.next();
    if (command2 == null) return;

    if (std.mem.eql(u8, command2.?, "startpos")) {
        brd.setBoardFromFEN(fen.start_position, board);

        var stillMoves = true;

        const command3 = split.next();
        if (command3 == null) return;
        if (std.mem.eql(u8, command3.?, "moves")) {
            while (stillMoves) {
                const move = split.next();
                if (move) |m| {
                    const parsedMove = parseMove(m, board.*);
                    if (parsedMove) |pm| {
                        const result = mv.MakeMove(pm, board, board.sideToMove);
                        if (!result) {
                            @panic("Invalid move received in position command");
                        }
                    }
                } else {
                    stillMoves = false;
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

        var stillMoves = true;

        const command3 = split.next();
        if (command3 == null) return;
        if (std.mem.eql(u8, command3.?, "moves")) {
            while (stillMoves) {
                const move = split.next();
                if (move) |m| {
                    const parsedMove = parseMove(m, board.*);
                    if (parsedMove) |pm| {
                        const result = mv.MakeMove(pm, board, board.sideToMove);
                        if (!result) {
                            @panic("Invalid move received in position command");
                        }
                    }
                } else {
                    stillMoves = false;
                }
            }
        }
    }
}

pub fn Go(board: *brd.Board, tokens: []const u8) !void {
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
            const depthInt = try std.fmt.parseInt(u8, d, 10);
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            const allocator = arena.allocator();
            var list = std.ArrayList(mv.Move).init(allocator);
            defer list.deinit();
            const startTime = std.time.milliTimestamp();
            const pos = try perft.Perft(board, list, depthInt, depthInt, board.sideToMove, allocator);
            const endTime = std.time.milliTimestamp();
            const diff: u64 = @intCast(endTime - startTime);
            try stdout.print("\nMoves: {}", .{pos.Nodes});
            try stdout.print("\nCaptures: {}", .{pos.Captures});
            try stdout.print("\nEnPassant: {}", .{pos.EnPassant});
            try stdout.print("\nPromotions: {}", .{pos.Promotions});
            try stdout.print("\nCastles: {}", .{pos.Castles});
            try stdout.print("\nElapsed Time: {} ms", .{diff});
            try stdout.print("\nMove Generationg Time: {} ms", .{pos.GenerationTime});
            try stdout.print("\nMake Move Time: {} ms\n", .{pos.MakeTime});
        }
    }
}
