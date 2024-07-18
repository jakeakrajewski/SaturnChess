const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const eval = @import("Evaluate.zig");

var killerMoves: [128][2]mv.Move = undefined;
var historyMoves: [64][12]i32 = undefined;
var pvLength: [64]i32 = undefined;
var pvTable: [64][64]mv.Move = undefined;
var ply: u16 = 0;

pub fn Search(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8, halfMove: u16) !mv.Move {
    var moves = moveList;
    ply = halfMove;
    var bestMove: mv.Move = undefined;
    var bestScore: i64 = -1000000;
    var alpha: i64 = -1000000;
    const beta: i64 = 1000000;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
    if (moves.items.len > 0) sortMoves(&moves, board);
    for (0..moves.items.len) |m| {
        var b = board.*;
        const move = moves.items[m];
        const start = try sqr.Square.fromIndex(move.source);
        const target = try sqr.Square.fromIndex(move.target);
        // const newList = moveList;
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) continue;
        const score = -(try NegaMax(&b, moveList, depth - 1, -beta, -alpha));
        std.debug.print("Move: {s}{s} Score: {}\n ", .{ start.toString(), target.toString(), score });
        if (score > bestScore) {
            bestScore = score;
            bestMove = move;
        }
        if (score > alpha) {
            alpha = score;
        }
    }
    if (bestScore == -1000000) {
        return moves.items[0];
    } else {
        return bestMove;
    }
}

fn NegaMax(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8, alpha: i64, beta: i64) !i64 {
    ply += 1;
    pvLength[ply] = ply;

    if (depth == 0) {
        ply -= 1;
        return Quiesce(board, moveList, alpha, beta);
    }
    var a = alpha;
    var moves = moveList;
    var score = a;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
    if (moves.items.len > 0) sortMoves(&moves, board);
    if (moves.items.len == 0) {
        ply -= 1;
        const kingBoard = if (board.sideToMove == 0) board.wKing else board.bKing;
        const kingSquare: u6 = @intCast(bit.LeastSignificantBit(kingBoard));
        if (board.isSquareAttacked(kingSquare, board.sideToMove) > 0) {
            return -1000001;
        } else {
            return 0;
        }
    }

    for (0..moves.items.len) |m| {
        var b = board.*;
        const move = moves.items[m];
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) continue;
        // const newList = moveList;
        score = -(try NegaMax(&b, moveList, depth - 1, -beta, -a));
        if (score > a) {
            if (!move.isCapture) {
                historyMoves[move.target][@intFromEnum(move.piece)] += depth;
            }
            
						pvTable[ply][ply] = move;

            for (ply + 1..pvLength[ply + 1]) |nextPly| {
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

    ply -= 1;
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
    if (moves.items.len > 0) sortMoves(&moves, board);
    for (0..moves.items.len) |m| {
        const move = moves.items[m];
        if (!move.isCapture) continue;
        var b = board.*;
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) continue;
        // const newList = moveList;
        score = -(try Quiesce(&b, moveList, -beta, -a));
        if (score > a) a = score;
        if (score >= beta) break;
    }

    return a;
}

fn sortMoves(moveList: *std.ArrayList(mv.Move), board: *brd.Board) void {
    var scores = std.ArrayList(i32).init(std.heap.page_allocator);
    defer scores.deinit();

    for (moveList.items) |m| {
        const score = ScoreMove(m, board);
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

fn ScoreMove(move: mv.Move, board: *brd.Board) i32 {
    var score: i32 = 0;

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
