pub const std = @import("std");

pub var config: Config = undefined;

pub const Config = struct {
    killer_moves: bool,// Done
    history: bool, //Done
    pv_tables: bool, //Done
    late_move: bool, //Done
    null_move: bool, //Done
    transposition_tables: bool, //Done
    static_exchange: bool, //Done
    isolated_pawns: bool,
    backwards_pawns: bool,
    doubled_pawns: bool,
    connected_pawns: bool,
    piece_square_tables: bool,
    bishop_king_ring: bool,
    mobility: bool,
    rook_king_ring: bool,
    rook_on_queen: bool,
    rook_open: bool,
    minor_behind: bool,
    bishop_pair: bool,
    long_bishops: bool,
    king_safety: bool,
    open_king: bool,
    pawn_square_score: bool,
    space_score: bool,
    material_score: bool,

    pub fn parseFromJson(allocator: std.mem.Allocator, source: []const u8) !void {
        const parsed = try std.json.parseFromSlice(Config, allocator, source, .{});
        defer parsed.deinit();
        config = parsed.value;
    }
};
