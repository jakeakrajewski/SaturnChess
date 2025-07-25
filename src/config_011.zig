pub const config = @import("config.zig").Config{
    .killer_moves = true,
    .history = true,
    .pv_tables = true,
    .late_move = true,
    .null_move = true,
    .transposition_tables = true,
    .static_exchange = true,
    .isolated_pawns = true,
    .backwards_pawns = true,
    .doubled_pawns = true,
    .connected_pawns = true,
    .piece_square_tables = false,
    .bishop_king_ring = true,
    .mobility = true,
    .rook_king_ring = true,
    .rook_on_queen = true,
    .rook_open = true,
    .minor_behind = true,
    .bishop_pair = true,
    .long_bishops = true,
    .king_safety = true,
    .open_king = true,
    .pawn_square_score = true,
    .space_score = true,
    .material_score = true,
};
