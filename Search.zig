const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const eval = @import("Evaluate.zig");

const maxPly = 64;
var nodes: i64 = 0;
var killerMoves: [maxPly][2]mv.Move = undefined;
var historyMoves: [64][12]i32 = undefined;
var pvLength: [maxPly]i32 = undefined;
var pvTable: [maxPly][maxPly]mv.Move = undefined;
var ply: u16 = 0;
var followPV: u1 = 0;
var scorePV: u1 = 0;

pub fn Search(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8) !mv.Move {
    nodes = 0;
    followPV = 0;
    scorePV = 0;

    for (&killerMoves) |*plyMoves| {
        @memset(plyMoves, mv.fromU24(0));
    }
    for (&historyMoves) |*history| {
        @memset(history, 0);
    }
    for (&pvTable) |*pv| {
        @memset(pv, mv.fromU24(0));
    }
    @memset(&pvLength, 0);

    const b = board;
    ply = 0;
    for (1..depth + 1) |d| {
        followPV = 1;
        const score = try NegaMax(b, moveList, @intCast(d), -1000000, 1000000);
        try std.io.getStdOut().writer().print("info score cp {} depth {} nodes {} pv ", .{ score, d, nodes });
        for (0..@intCast(pvLength[ply])) |count| {
            try PrintMove(pvTable[0][count]);
        }
        try std.io.getStdOut().writer().print("\n", .{});
    }
    return pvTable[0][0];
}

fn EnablePVScoring(moveList: std.ArrayList(mv.Move)) void {
    followPV = 0;

    for (0..moveList.items.len) |count| {
        if (pvTable[0][ply].Equals(moveList.items[count])) {
            scorePV = 1;
            followPV = 1;
        }
    }
}

fn NegaMax(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8, alpha: i64, beta: i64) !i64 {
    pvLength[ply] = ply;

    if (depth == 0) {
        return Quiesce(board, moveList, alpha, beta);
    }
    if (ply > maxPly - 1) {
        return eval.Evaluate(board.*);
    }
    var a = alpha;
    var moves = moveList;
    var score = a;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
    if (followPV == 1) {
        EnablePVScoring(moves);
    }
    if (moves.items.len > 0) try sortMoves(&moves, board);
    if (moves.items.len == 0) {
        const kingBoard = if (board.sideToMove == 0) board.wKing else board.bKing;
        const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
        if (board.isSquareAttacked(kingSquare, board.sideToMove) > 0) {
            return -1000001;
        } else {
            return 0;
        }
    }

    for (0..moves.items.len) |m| {
        nodes += 1;
        ply += 1;
        var b = board.*;
        const move = moves.items[m];
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) {
            ply -= 1;
            continue;
        }
        score = -(try NegaMax(&b, moveList, depth - 1, -beta, -a));
        ply -= 1;

        if (score > a) {
            if (!move.isCapture) {
                historyMoves[move.target][@intFromEnum(move.piece)] += depth;
            }

            pvTable[ply][ply] = move;

            for (ply + 1..@intCast(pvLength[ply + 1])) |nextPly| {
                pvTable[ply][nextPly] = pvTable[ply + 1][nextPly];
            }

            pvLength[ply] = pvLength[ply + 1];

            a = score;
        }
        if (score >= beta) {
            if (!move.isCapture) {
                killerMoves[ply][1] = killerMoves[ply][0];
                killerMoves[ply][0] = move;
            }
            break;
        }
    }

    return a;
}

fn Quiesce(board: *brd.Board, moveList: std.ArrayList(mv.Move), alpha: i64, beta: i64) !i64 {
    var a = alpha;
    const ev = eval.Evaluate(board.*);
    if (ev >= beta) return beta;
    if (ev > a) a = ev;
    var moves = moveList;
    var score = a;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
    if (moves.items.len > 0) try sortMoves(&moves, board);
    for (0..moves.items.len) |m| {
        ply += 1;
        const move = moves.items[m];
        if (!move.isCapture) {
            ply -= 1;
            continue;
        }
        var b = board.*;
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) {
            ply -= 1;
            continue;
        }
        score = -(try Quiesce(&b, moveList, -beta, -a));
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
        const score = try ScoreMove(m, board);
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

                const tmpMove = moveList.items[j];
                moveList.items[j] = moveList.items[j + 1];
                moveList.items[j + 1] = tmpMove;
            }
        }
    }
}

fn ScoreMove(move: mv.Move, board: *brd.Board) !i32 {
    var score: i32 = 0;
    if (scorePV == 1 and pvTable[0][ply].Equals(move)) {
        try std.io.getStdOut().writer().print("current PV move: ", .{});
        try PrintMove(move);
        try std.io.getStdOut().writer().print("ply: {}\n", .{ply});

        scorePV = 0;
        return 20000;
    }
    if (move.isCapture) {
        score += ScoreCapture(move, board) + 10000;
    } else {
        if (killerMoves[ply][0].Equals(move)) return 9000;
        if (killerMoves[ply][1].Equals(move)) return 8000;
        return historyMoves[move.target][@intFromEnum(move.piece)];
    }

    return score;
}

fn ScoreCapture(move: mv.Move, board: *brd.Board) i32 {
    const pieceValue = GetPieceValue(move.piece);
    const targetPiece = board.GetPieceAtSquare(move.target);

    if (targetPiece) |tp| {
        return GetPieceValue(tp) - pieceValue;
    }
    return 0;
}

fn GetPieceValue(piece: brd.Pieces) i32 {
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

fn PrintMove(move: mv.Move) !void {
    const pvstart = try sqr.Square.fromIndex(move.source);
    const pvtarget = try sqr.Square.fromIndex(move.target);
    try std.io.getStdOut().writer().print("{s}{s} ", .{ pvstart.toString(), pvtarget.toString() });
}
