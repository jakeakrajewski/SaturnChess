const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const map = @import("Maps.zig");
const eval = @import("Evaluate.zig");
const zob = @import("Zobrist.zig");
const uci = @import("UCI.zig");

pub const config = @import("main.zig").config;

pub const inifintity: i64 = 50000;
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
var positions_reached: [max_ply]u64 = undefined;
pub var transposition_tables: [zob.hash_size]zob.TranspositionTable = undefined;
pub const mate_value: i64 = 49000;
pub const mate_score: i64 = 48000;
pub var best_move: ?mv.Move = null;
pub var prev_score: i64 = -inifintity;
var highest_ply: u16 = 0;

pub fn Search(board: *brd.Board, moveList: *std.ArrayList(mv.Move), depth: u8, timedSearch: bool, time: i64) !mv.Move {
    const stdout = std.io.getStdOut().writer();
    const start_time = std.time.milliTimestamp();
    timed_search = timedSearch;
    nodes = 0;
    follow_pv = 0;
    score_pv = 0;
    search_start_time_stamp = std.time.milliTimestamp();
    time_allowance = time;
    stop_search = false;
    highest_ply = 0;

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
    @memset(&positions_reached, 0);

    const b = board;
    ply = 0;

    var alpha: i64 = -1000000;
    var beta: i64 = 1000000;

    //Iterative Deepening
    for (1..depth + 1) |d| {
        if (timed_search) {
            const current_time = std.time.milliTimestamp();
            if (current_time - search_start_time_stamp > time_allowance or stop_search) break;
        }

        // Use pv_table from previous depth if search ends early
        prev_pv_table = pv_table;
        if (config.pv_tables) follow_pv = 1;
        var score = try negaScout(b, moveList, @intCast(d), alpha, beta);

        // Aspiration Window Adjustments
        if (score <= alpha or score >= beta) {
            alpha = -inifintity;
            beta = inifintity;
            score = try negaScout(b, moveList, @intCast(d), alpha, beta);
        } else {
            alpha = score - 50;
            beta = score + 50;
        }

        const end_time = std.time.milliTimestamp();
        const elapsed_time: i64 = end_time - start_time;
        if (score > -mate_value and score < -mate_score) {
            stop_search = true;
            try stdout.print("info score mate {} depth {} nodes {} time {} pv ", .{ @divFloor(-(score + mate_value), 2) - 1, d, nodes, elapsed_time });
        } else if (score > mate_score and score < mate_value) {
            try stdout.print("info score mate {} depth {} nodes {} time {} pv ", .{ @divFloor((mate_value - score), 2) + 1, d, nodes, elapsed_time });
        } else {
            try stdout.print("info score cp {} depth {} nodes {} time {} pv ", .{ score, d, nodes, elapsed_time });
        }

        for (0..@intCast(pv_length[ply])) |count| {
            try printMove(pv_table[0][count]);
        }
        try stdout.print("\n", .{});
    }
    std.debug.print("\nLowest Depth Searched: {}", .{highest_ply});
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
                std.debug.print("\nSearch Stopped!\n", .{});
                stop_search = true;
                return 0;
            }
        }
    }

    // Detect Three Fold Repetition (Draw)
    if (countOccurences(&positions_reached, board.hashKey) + countOccurences(&uci.positions, board.hashKey) > 2) return 0;

    var hash_flag: u2 = 1;

    // Determine if current node is PV
    const is_pv_node = b - a > 1;

    var score: i64 = 0;
    // Search Transposition Tables For Current Position
    if (config.transposition_tables){
        score = zob.probeTT(board.*, &transposition_tables, depth, a, b, ply);
        if (ply > 0 and score != 100000 and !is_pv_node) {
            pv_length[ply] = ply;
            return score;
        }
    }

    pv_length[ply] = ply;
    var alpha = a;
    const beta = b;

    // Quiescence Search
    if (depth <= 0) {
        return quiesce(board, moveList, alpha, beta);
    }
    if (ply > max_ply - 1) {
        return eval.evaluate(board.*);
    }

    const king_board = if (board.sideToMove == 0) board.wKing else board.bKing;
    const king_square: u6 = @intCast(bit.leastSignificantBit(king_board));

    // Null Move Heuristic
    if (config.null_move){
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
    }

    var moves = std.ArrayList(mv.Move).init(moveList.allocator);
    defer moves.deinit();
    try mv.generateMoves(&moves, board, board.sideToMove);
    if (follow_pv == 1) {
        enablePVScoring(&moves);
    }

    // Move Ordering
    if (moves.items.len > 0) try sortMoves(&moves, board);

    // Detect Checkmate or Stalemate
    if (moves.items.len == 0) {
        if (board.isSquareAttacked(king_square, board.sideToMove) > 0) {
            return -mate_value + ply;
        } else {
            return 0;
        }
    }
    var moves_searched: u16 = 0;

    for (0..moves.items.len) |m| {
        if (stop_search) break;
        nodes += 1;
        ply += 1;
        if (ply > highest_ply) highest_ply = ply;
        var board_copy = board.*;
        var move = moves.items[m];
        const result = mv.makeMove(move, &board_copy, board_copy.sideToMove);
        positions_reached[ply] = board_copy.hashKey;
        if (!result) {
            ply -= 1;
            continue;
        }

        // Principal Variation (PV) Search
        if (moves_searched == 0) {
            score = -(try negaScout(&board_copy, moveList, depth - 1, -beta, -alpha));
        } else {
            // Late Move Reduction
            if (config.late_move){
                if (moves_searched >= 4 and
                    !is_pv_node and
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
        }

        moves_searched += 1;

        positions_reached[ply] = 0;
        ply -= 1;

        if (score > alpha) {
            hash_flag = 0;
            best_move = move;

            // History Move Heuristics
            if (!move.isCapture) {
                history_moves[move.target][@intFromEnum(move.piece)] += depth;
            }

            if (pv_length[ply + 1] != 0) {

                // Update PV Table
                pv_table[ply][ply] = move;
                for (ply + 1..@intCast(pv_length[ply + 1])) |next_ply| {
                    pv_table[ply][next_ply] = pv_table[ply + 1][next_ply];
                }

                pv_length[ply] = pv_length[ply + 1];
            }

            alpha = score;
        }
        if (score >= beta) {
            // Write Beta Cutoff To Transposition Tables
            zob.writeTT(board.*, &transposition_tables, null, beta, 2, depth, ply);

            // Killer Move Heuristic
            if (!move.isCapture) {
                killer_moves[ply][1] = killer_moves[ply][0];
                killer_moves[ply][0] = move;
            }

            return beta;
        }
    }

    zob.writeTT(board.*, &transposition_tables, best_move, alpha, hash_flag, depth, ply);
    return alpha;
}

fn quiesce(board: *brd.Board, moveList: *std.ArrayList(mv.Move), alpha: i64, beta: i64) !i64 {
    if (timed_search) {
        time_check -= 1;
        if (time_check == 0) {
            time_check = 200;
            if (std.time.milliTimestamp() - search_start_time_stamp > time_allowance) {
                std.debug.print("\nSearch Stopped!\n", .{});
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
    try mv.generateCaptures(&moves, board, board.sideToMove);
    if (moves.items.len > 0) try sortMoves(&moves, board);
    for (0..moves.items.len) |m| {
        if (stop_search) break;
        ply += 1;
        if (ply > highest_ply) highest_ply = ply;
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
    var current_move = move;
    if (best_move) |m| {
        if (current_move.Equals(m)) {
            return 30000;
        }
    }
    if (score_pv == 1 and pv_table[0][ply].Equals(move)) {
        score_pv = 0;
        return 20000;
    }
    if (move.isCapture) {
        const m = board.GetPieceAtSquare(move.target);
        if (m) |_| {
            if (config.static_exchange) score += staticExchangeDriver(move, board) + 10000;
        } else {
            const ep_square = board.getEpSquare();
            if (ep_square) |ep| {
                if (move.target == ep) {
                    return getPieceValue(move.piece) - 100;
                }
                bit.print(board.allPieces());
                printMoveDebug(move);
                @panic("Something weird is happening");
            }
        }
    } else {
        if (config.killer_moves){
        if (killer_moves[ply][0].Equals(move)) return 9000;
        if (killer_moves[ply][1].Equals(move)) return 8000;
        }
        if (config.history){
            return history_moves[move.target][@intFromEnum(move.piece)];
        }
    }

    return score;
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

pub fn staticExchangeDriver(move: mv.Move, board: *brd.Board) i32 {
    const target_square = move.target;
    var b = board.*;
    var score: i32 = 0;

    const captured_piece = b.GetPieceAtSquare(target_square);

    if (captured_piece) |piece| {
        b.updateBoard(move.piece, move.source, target_square, board.sideToMove, (target_square == bit.leastSignificantBit(board.enPassantSquare)));
        b.sideToMove ^= 1;
        score = getPieceValue(piece) - staticExchangeEvaluation(target_square, b);
    }
    return score;
}

pub fn staticExchangeEvaluation(square: u6, board: brd.Board) i32 {
    var score: i32 = 0;
    var b = board;
    const captured_piece = b.GetPieceAtSquare(square);

    if (captured_piece) |cp| {
        const least_valuable_square = getLeastValuableAttacker(square, board);
        if (least_valuable_square) |lvs| {
            const piece = b.GetPieceAtSquare(lvs);
            if (piece) |p| {
                const ep_square = b.getEpSquare();
                var is_ep = false;
                if (ep_square) |ep| {
                    is_ep = square == ep;
                }
                b.updateBoard(p, lvs, square, b.sideToMove, is_ep);
                b.sideToMove ^= 1;

                b.enPassantSquare = 0;
                score = getPieceValue(cp) - staticExchangeEvaluation(square, b);
            }
        }
    }

    return score;
}

pub fn getLeastValuableAttacker(square: u6, board: brd.Board) ?u6 {
    var b = board;
    const pawns = if (board.sideToMove == 1) board.bPawns else board.wPawns;
    const pawn_attack = map.pawn_attacks[~board.sideToMove][square];

    if (pawn_attack & pawns > 0) return @intCast(bit.leastSignificantBit(pawn_attack & pawns));

    const knights = if (board.sideToMove == 1) board.bKnights else board.wKnights;
    const knight_attacks = map.knight_attacks[square];

    if (knight_attacks & knights > 0) return @intCast(bit.leastSignificantBit(knight_attacks & knights));

    const bishops = if (board.sideToMove == 1) board.bBishops else board.wBishops;
    const bishop_attacks = map.getBishopAttacks(square, b.allPieces());

    if (bishop_attacks & bishops > 0) return @intCast(bit.leastSignificantBit(bishop_attacks & bishops));

    const rooks = if (board.sideToMove == 1) board.bRooks else board.wRooks;
    const rook_attacks = map.getRookAttacks(square, b.allPieces());

    if (rook_attacks & rooks > 0) return @intCast(bit.leastSignificantBit(rook_attacks & rooks));

    const queens = if (board.sideToMove == 1) board.bQueens else board.wQueens;
    const queen_attacks = bishop_attacks | rook_attacks;

    if (queen_attacks & queens > 1) return @intCast(bit.leastSignificantBit(queen_attacks & queens));

    const king = if (board.sideToMove == 1) board.bKing else board.wKing;
    const king_attacks = map.king_attacks[square];

    if (king_attacks & king > 1) return @intCast(bit.leastSignificantBit(king));

    return null;
}

fn printMove(move: mv.Move) !void {
    var m = move;
    const source = try sqr.Square.FromIndex(move.source);
    const target = try sqr.Square.FromIndex(move.target);
    if (m.isPromotion()) {
        try std.io.getStdOut().writer().print("{s}{s}{s} ", .{ source.toString(), target.toString(), m.promotionChar() });
    } else {
        try std.io.getStdOut().writer().print("{s}{s} ", .{ source.toString(), target.toString() });
    }
}
fn printMoveDebug(move: mv.Move) void {
    var m = move;
    const source = try sqr.Square.FromIndex(move.source);
    const target = try sqr.Square.FromIndex(move.target);
    if (m.isPromotion()) {
        std.debug.print("{s}{s}{s} ", .{ source.toString(), target.toString(), m.promotionChar() });
    } else {
        std.debug.print("{s}{s} ", .{ source.toString(), target.toString() });
    }
}
fn countOccurences(list: []u64, val: u64) u8 {
    var count: u8 = 0;
    for (0..list.len) |i| {
        if (list[i] == val) count += 1;
    }
    return count;
}
