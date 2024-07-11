const brd = @import("Board.zig");
const mv = @import("Moves.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const std = @import("std");
const eval = @import("Evaluate.zig");

pub fn Search(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8) !mv.Move {
    var moves = moveList;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
    var bestScore: i64 = -1000000;
    var bestMove: mv.Move = undefined;
    for (0..moves.items.len) |m| {
        var b = board.*;
        const move = moves.items[m];
        const newList = moveList;
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) continue;
        const score = try NegaMax(&b, newList, depth - 1);
        if (score > bestScore) {
            bestScore = score;
            bestMove = move;
        }
    }

    return bestMove;
}

fn NegaMax(board: *brd.Board, moveList: std.ArrayList(mv.Move), depth: u8) !i64 {
    if (depth == 0) return eval.Evaluate(board.*);
    var moves = moveList;
    var max: i64 = -1000000;
    var score = max;
    try mv.GenerateMoves(&moves, board, board.sideToMove);
    for (0..moves.items.len) |m| {
        var b = board.*;
        const move = moves.items[m];
        const result = mv.MakeMove(move, &b, b.sideToMove);
        if (!result) continue;
        const newList = moveList;
        score = try NegaMax(&b, newList, depth - 1);
        if (-score > max) max = -score;
    }

    return score;
}
