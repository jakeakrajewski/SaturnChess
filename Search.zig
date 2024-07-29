const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const eval = @import("Evaluate.zig");
const zob = @import("Zobrist.zig");

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
var timed_search = false;
var aspiration_window_adjustment = 50;
var transposition_tables: [zob.hash_size]zob.TranspositionTable = undefined;

pub fn Search(board: *brd.Board, moveList: *std.ArrayList(mv.Move), depth: u8, timedSearch: bool, time: i64) !mv.Move {
    const start_time = std.time.milliTimestamp();
    timed_search = timedSearch;
    nodes = 0;
    follow_pv = 0;
    score_pv = 0;
    search_start_time_stamp = std.time.milliTimestamp();
    time_allowance = time;
    stop_search = false;

    // place this at inititalization
    // for (0..transposition_tables.len) |t| {
    //     transposition_tables[t].key = 0;
    //     transposition_tables[t].depth = 0;
    //     transposition_tables[t].flags = 0;
    //     transposition_tables[t].score = 0;
    // }
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

    var alpha: i64 = -1000000;
    var beta: i64 = 1000000;
    for (1..depth + 1) |d| {
        if (timed_search) {
            const current_time = std.time.milliTimestamp();
            if (current_time - search_start_time_stamp > time_allowance) break;
        }
        prev_pv_table = pv_table;
        follow_pv = 1;
        const score = try negaScout(b, moveList, @intCast(d), alpha, beta);

        if (score <= alpha or score >= beta) {
            alpha = -50000;
            beta = 50000;
            continue;
        }

        alpha = score - 50;
        beta = score + 50;

        const end_time = std.time.milliTimestamp();
        const elapsed_time: i64 = end_time - start_time;
        try std.io.getStdOut().writer().print("info score cp {} depth {} nodes {} time {} pv ", .{ score, d, nodes, elapsed_time });
        for (0..@intCast(pv_length[ply])) |count| {
            try printMove(pv_table[0][count]);
        }
        try std.io.getStdOut().writer().print("\n", .{});
    }

    if (stop_search) {
        return prev_pv_table[0][0];
    } else {
        return pv_table[0][0];
    }
}

fn enablePVScoring(moveList: *std.ArrayList(mv.Move)) void {
    follow_pv = 0;

    for (0..moveList.items.len) |count| {
        if (pv_table[0][ply].Equals(moveList.items[count])) {
            score_pv = 1;
            follow_pv = 1;
        }
    }
}

fn negaScout(board: *brd.Board, moveList: *std.ArrayList(mv.Move), depth: i8, a: i64, b: i64) !i64 {
    if (timed_search) {
        time_check -= 1;
        if (time_check == 0) {
            time_check = 200;
            if (std.time.milliTimestamp() - search_start_time_stamp > time_allowance) {
                std.debug.print("\n Search Stopped!", .{});
                stop_search = true;
                return 0;
            }
        }
    }

    var hash_flag: u2 = 1;

    var score = a;
    // var score = zob.probeTT(board.*, &transposition_tables, depth, a, b);
    // if (ply > 0 and score != 100000) {
    //     pv_length[ply] = ply;
    //     return score;
    // }

    pv_length[ply] = ply;
    var alpha = a;
    const beta = b;

    if (depth <= 0) {
        return quiesce(board, moveList, alpha, beta);
    }
    if (ply > max_ply - 1) {
        return eval.evaluate(board.*);
    }
    var moves = std.ArrayList(mv.Move).init(moveList.allocator);
    defer moves.deinit();

    const king_board = if (board.sideToMove == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));
    //Null Move Pruning
    if (depth >= 3 and
        board.isSquareAttacked(king_square, board.sideToMove) == 0 and
        ply > 0 and
        !eval.isEndGame(board.*))
    {
        var null_copy = board.*;
        ply += 1;
        null_copy.sideToMove = if (null_copy.sideToMove == 1) 0 else 1;
        null_copy.enPassantSquare = 0;
        null_copy.hashKey ^= zob.side_key;
        if (board.enPassantSquare != 0) null_copy.hashKey ^= zob.enpassant_keys[bit.leastSignificantBit(board.enPassantSquare)];
        const temp_score = -(try negaScout(&null_copy, moveList, depth - 3, -beta, -beta + 1));
        ply -= 1;
        if (temp_score >= beta) {
            return beta;
        }
    }

    try mv.generateMoves(&moves, board, board.sideToMove);
    if (follow_pv == 1) {
        enablePVScoring(&moves);
    }
    if (moves.items.len > 0) try sortMoves(&moves, board);
    if (moves.items.len == 0) {
        if (board.isSquareAttacked(king_square, board.sideToMove) > 0) {
            return -1000001;
        } else {
            return 0;
        }
    }
    var moves_searched: u16 = 0;

    for (0..moves.items.len) |m| {
        if (stop_search) break;
        nodes += 1;
        ply += 1;
        var board_copy = board.*;
        var move = moves.items[m];
        const result = mv.makeMove(move, &board_copy, board_copy.sideToMove);
        if (!result) {
            ply -= 1;
            continue;
        }
        if (moves_searched == 0) {
            score = -(try negaScout(&board_copy, moveList, depth - 1, -beta, -alpha));
        } else {
            if (moves_searched >= 4 and
                ply >= 3 and
                !move.isCapture and
                board.isSquareAttacked(king_square, board.sideToMove) == 0 and
                !move.isPromotion())
            {
                score = -(try negaScout(&board_copy, moveList, depth - 2, -alpha - 1, -alpha));
            } else {
                score = alpha + 1;
            }

            if (score > alpha) {
                score = -(try negaScout(&board_copy, moveList, depth - 1, -alpha - 1, -alpha));
                if (score > alpha and score < beta) {
                    score = -(try negaScout(&board_copy, moveList, depth - 1, -beta, -alpha));
                }
            }
        }
        moves_searched += 1;

        ply -= 1;

        if (score > alpha) {
            hash_flag = 0;
            if (!move.isCapture) {
                history_moves[move.target][@intFromEnum(move.piece)] += depth;
            }

            pv_table[ply][ply] = move;
            for (ply + 1..@intCast(pv_length[ply + 1])) |next_ply| {
                pv_table[ply][next_ply] = pv_table[ply + 1][next_ply];
            }

            pv_length[ply] = pv_length[ply + 1];

            alpha = score;
        }
        if (score >= beta) {
            zob.writeTT(board.*, &transposition_tables, beta, 2, depth);
            if (!move.isCapture) {
                killer_moves[ply][1] = killer_moves[ply][0];
                killer_moves[ply][0] = move;
            }

            break;
        }
    }

    zob.writeTT(board.*, &transposition_tables, alpha, hash_flag, depth);
    return alpha;
}

fn quiesce(board: *brd.Board, moveList: *std.ArrayList(mv.Move), alpha: i64, beta: i64) !i64 {
    if (timed_search) {
        time_check -= 1;
        if (time_check == 0) {
            time_check = 200;
            if (std.time.milliTimestamp() - search_start_time_stamp > time_allowance) {
                std.debug.print("\n Search Stopped!", .{});
                stop_search = true;
                return eval.evaluate(board.*);
            }
        }
    }
    var a = alpha;
    const ev = eval.evaluate(board.*);
    if (ply > max_ply - 1) {
        return ev;
    }
    if (ev >= beta) return beta;
    if (ev > a) a = ev;
    var moves = std.ArrayList(mv.Move).init(moveList.allocator);
    defer moves.deinit();
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
        if (score > a) {
            a = score;
        }
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
        std.debug.print("PV Move Ply {}: ", .{ply});
        score_pv = 0;
        printMoveDebug(move);
        std.debug.print("\n", .{});
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
        return getPieceValue(tp) - pieceValue;
    }
    return 0;
}
fn getPieceValue(piece: brd.Pieces) i32 {
    switch (piece) {
        .P, .p => {
            return 100;
        },
        .N, .n => {
            return 300;
        },
        .B, .b => {
            return 300;
        },
        .R, .r => {
            return 500;
        },
        .Q, .q => {
            return 900;
        },
        else => {
            return 0;
        },
    }
}

fn printMove(move: mv.Move) !void {
    const source = try sqr.Square.FromIndex(move.source);
    const target = try sqr.Square.FromIndex(move.target);
    try std.io.getStdOut().writer().print("{s}{s} ", .{ source.toString(), target.toString() });
}
fn printMoveDebug(move: mv.Move) void {
    const source = try sqr.Square.FromIndex(move.source);
    const target = try sqr.Square.FromIndex(move.target);
    std.debug.print("{s}{s} ", .{ source.toString(), target.toString() });
}
