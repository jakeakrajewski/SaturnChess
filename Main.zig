const std = @import("std");
const map = @import("Maps.zig");
const bit = @import("BitManipulation.zig");
const sqr = @import("Square.zig");
const rand = @import("Rand.zig");
const brd = @import("Board.zig");
const fen = @import("FenStrings.zig");
const mv = @import("Moves.zig");
const perft = @import("Perft.zig");
const uci = @import("UCI.zig");
const eval = @import("Evaluate.zig");
const builtin = @import("builtin");
const zob = @import("Zobrist.zig");
const ser = @import("Search.zig");

pub fn main() !void {
    try map.initializeAttackTables();
    try uci.uciLoop();
}
