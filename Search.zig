const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const eval = @import("Evaluate.zig");

const max_ply = 64;
var nodes: i64 = 0;
var killer_moves: [max_ply][2]mv.Move = undefined;
var history_moves: [64][12]i32 = undefined;
var pv_length: [max_ply]i32 = undefined;
var pv_table: [max_ply][max_ply]mv.Move = undefined;
var prev_pv_table: [max_ply][max_ply]mv.Move = undefined;
var ply: u16 = 0;
var follow_pv: u1 = 0;
var score_pv: u1 = 0;
var search_start_time_stamp: i64 = 0;
var time_check: u16 = 200;
var time_allowance: i64 = 0;
var stop_search = false;

pub fn Search(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8, time: i64) !mv.Move {
    nodes = 0;
    follow_pv = 0;
    score_pv = 0;
    search_start_time_stamp = std.time.milliTimestamp();
    time_allowance = time;
    stop_search = false;

    for (&killer_moves) |*plyMoves| {
        @memset(plyMoves, mv.FromU24(0));
    }
    for (&history_moves) |*history| {
        @memset(history, 0);
    }
    for (&pv_table) |*pv| {
        @memset(pv, mv.FromU24(0));
    }
    @memset(&pv_length, 0);

    const b = board;
    ply = 0;
    for (1..depth + 1) |d| {
        const current_time = std.time.milliTimestamp();
        if (current_time - search_start_time_stamp > time_allowance) break;
        prev_pv_table = pv_table;
        follow_pv = 1;
        const score = try negaMax(b, moveList, @intCast(d), -1000000, 1000000);
        try std.io.getStdOut().writer().print("info score cp {} depth {} nodes {} pv ", .{ score, d, nodes });
        for (0..@intCast(pv_length[ply])) |count| {
            try printMove(pv_table[0][count]);
        }
        try std.io.getStdOut().writer().print("\n", .{});
    }

    std.debug.print("\nPV Table: \n", .{});
    for (0..8) |row| {
        std.debug.print("\nDepth {}: ", .{row});
        for (0..8) |i| {
            printMoveDebug(pv_table[row][i]);
        }
    }
    std.debug.print("\nPrevious PV Table: \n", .{});
    for (0..8) |row| {
        std.debug.print("\nDepth {}: ", .{row});
        for (0..8) |i| {
            printMoveDebug(prev_pv_table[row][i]);
        }
    }
    if (stop_search) {
        return prev_pv_table[0][0];
    } else {
        return pv_table[0][0];
    }
}

fn enablePVScoring(moveList: std.ArrayList(mv.Move)) void {
    follow_pv = 0;

    for (0..moveList.items.len) |count| {
        if (pv_table[0][ply].Equals(moveList.items[count])) {
            score_pv = 1;
            follow_pv = 1;
        }
    }
}

fn negaMax(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8, alpha: i64, beta: i64) !i64 {
    time_check -= 1;
    if (time_check == 0) {
        time_check = 200;
        if (std.time.milliTimestamp() - search_start_time_stamp > time_allowance) {
            std.debug.print("\n Search Stopped!", .{});
            stop_search = true;
            return 0;
        }
    }
    pv_length[ply] = ply;

    if (depth == 0) {
        return quiesce(board, moveList, alpha, beta);
    }
    if (ply > max_ply - 1) {
        return eval.evaluate(board.*);
    }
    var a = alpha;
    var moves = moveList;
    var score = a;
    try mv.generateMoves(&moves, board, board.sideToMove);
    if (follow_pv == 1) {
        enablePVScoring(moves);
    }
    if (moves.items.len > 0) try sortMoves(&moves, board);
    if (moves.items.len == 0) {
        const king_board = if (board.sideToMove == 0) board.wKing else board.bKing;
        const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
        if (board.isSquareAttacked(king_square, board.sideToMove) > 0) {
            return -1000001;
        } else {
            return 0;
        }
    }

    for (0..moves.items.len) |m| {
        if (stop_search) break;
        nodes += 1;
        ply += 1;
        var b = board.*;
        const move = moves.items[m];
        const result = mv.makeMove(move, &b, b.sideToMove);
        if (!result) {
            ply -= 1;
            continue;
        }
        score = -(try negaMax(&b, moveList, depth - 1, -beta, -a));
        ply -= 1;

        if (score > a) {
            if (!move.isCapture) {
                history_moves[move.target][@intFromEnum(move.piece)] += depth;
            }

            pv_table[ply][ply] = move;

            for (ply + 1..@intCast(pv_length[ply + 1])) |next_ply| {
                pv_table[ply][next_ply] = pv_table[ply + 1][next_ply];
            }

            pv_length[ply] = pv_length[ply + 1];

            a = score;
        }
        if (score >= beta) {
            if (!move.isCapture) {
                killer_moves[ply][1] = killer_moves[ply][0];
                killer_moves[ply][0] = move;
            }
            break;
        }
    }

    return a;
}

fn quiesce(board: *brd.Board, moveList: std.ArrayList(mv.Move), alpha: i64, beta: i64) !i64 {
    time_check -= 1;
    if (time_check == 0) {
        time_check = 200;
        if (std.time.milliTimestamp() - search_start_time_stamp > time_allowance) {
            std.debug.print("\n Search Stopped!", .{});
            stop_search = true;
            return eval.evaluate(board.*);
        }
    }
    var a = alpha;
    const ev = eval.evaluate(board.*);
    if (ev >= beta) return beta;
    if (ev > a) a = ev;
    var moves = moveList;
    var score = a;
    try mv.generateMoves(&moves, board, board.sideToMove);
    if (moves.items.len > 0) try sortMoves(&moves, board);
    for (0..moves.items.len) |m| {
        if (stop_search) break;
        ply += 1;
        const move = moves.items[m];
        if (!move.isCapture) {
            ply -= 1;
            continue;
        }
        var b = board.*;
        const result = mv.makeMove(move, &b, b.sideToMove);
        if (!result) {
            ply -= 1;
            continue;
        }
        score = -(try quiesce(&b, moveList, -beta, -a));
        ply -= 1;
        if (score > a) a = score;
        if (score >= beta) break;
    }

    return a;
}

fn sortMoves(moveList: *std.ArrayList(mv.Move), board: *brd.Board) !void {
    var scores = std.ArrayList(i32).init(std.heap.page_allocator);
    defer scores.deinit();

    for (moveList.items) |m| {
        const score = try scoreMove(m, board);
        scores.append(score) catch unreachable;
    }

    const len = moveList.items.len;

    var sorted: bool = false;
    while (!sorted) {
        sorted = true;
        for (0..(len - 1)) |j| {
            if (scores.items[j] < scores.items[j + 1]) {
                sorted = false;
                const tmpScore = scores.items[j];
                scores.items[j] = scores.items[j + 1];
                scores.items[j + 1] = tmpScore;

                const temp_move = moveList.items[j];
                moveList.items[j] = moveList.items[j + 1];
                moveList.items[j + 1] = temp_move;
            }
        }
    }
}

fn scoreMove(move: mv.Move, board: *brd.Board) !i32 {
    var score: i32 = 0;
    if (score_pv == 1 and pv_table[0][ply].Equals(move)) {
        try std.io.getStdOut().writer().print("current PV move: ", .{});
        try printMove(move);
        try std.io.getStdOut().writer().print("ply: {}\n", .{ply});

        score_pv = 0;
        return 20000;
    }
    if (move.isCapture) {
        score += scoreCapture(move, board) + 10000;
    } else {
        if (killer_moves[ply][0].Equals(move)) return 9000;
        if (killer_moves[ply][1].Equals(move)) return 8000;
        return history_moves[move.target][@intFromEnum(move.piece)];
    }

    return score;
}

fn scoreCapture(move: mv.Move, board: *brd.Board) i32 {
    const pieceValue = getPieceValue(move.piece);
    const targetPiece = board.GetPieceAtSquare(move.target);

    if (targetPiece) |tp| {
        retu