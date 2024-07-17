const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const eval = @import("Evaluate.zig");

pub fn Search(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8) !mv.Move {
    var moves = moveList;
    var bestMove: mv.Move = undefined;
    var bestScore: i64 = -1000000;
    var alpha: i64 = -1000000;
    const beta: i64 = 1000000;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
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
    if (depth == 0) return Quiesce(board, moveList, alpha, beta);
    var a = alpha;
    var moves = moveList;
    var score = a;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
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
        var b = board.*;
        const move = moves.items[m];
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) continue;
        // const newList = moveList;
        score = -(try NegaMax(&b, moveList, depth - 1, -beta, -a));
        if (score > a) a = score;
        if (score >= beta) break;
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

fn ScoreMove(move: mv.Move, board: brd.Board) i32 {
    var score: i32 = 0;

    if (move.isCapture()) {
        score += ScoreCapture(move, board);
    }

    return score;
}

fn ScoreCapture(move: mv.Move, board: brd.Board) i32 {
    const pieceValue = GetPieceValue(move.piece);
    const targetPiece = board.GetPieceAtSquare(move.target);

    if (targetPiece != null) {
        return GetPieceValue(targetPiece) - pieceValue;
    }
}

fn GetPieceValue(piece: brd.Pieces) u32 {
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
        else => {},
    }
}
