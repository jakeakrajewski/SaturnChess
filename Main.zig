const std = @import("std");
const map = @import("Maps/Maps.zig");
const bit = @import("BitManipulation/BitManipulation.zig");
const sqr = @import("Board/Square.zig");
const rand = @import("Random/Rand.zig");

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn().reader();

pub fn main() !void {
    try map.GenerateLeaperAttacks();

    try rand.InitMagicNumbers();
}
