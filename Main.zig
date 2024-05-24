const std = @import("std");
const map = @import("Maps/Maps.zig");
const bit = @import("BitManipulation/BitManipulation.zig");
const sqr = @import("Board/Square.zig");

pub fn main() !void {
    try bit.Print(map.MaskBishopAttacks(.E4));
}
