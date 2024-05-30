const std = @import("std");
const map = @import("Maps/Maps.zig");
const bit = @import("BitManipulation/BitManipulation.zig");
const sqr = @import("Board/Square.zig");

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn().reader();

pub fn main() !void {
    try map.GenerateLeaperAttacks();
    var attackMask: u64 = map.MaskBishopAttacks(.E4);
    try bit.Print(attackMask);

    for (0..4096) |index| {
        const occupancy: u64 = bit.SetOccupancy(index, &attackMask);
        try bit.Print(occupancy);
        _ = try stdin.readByte();
    }
}
