pub const Square = enum {
    // zig fmt: off
    A8, B8, C8, D8, E8, F8, G8, H8,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A1, B1, C1, D1, E1, F1, G1, H1,
    XX,

    pub fn toIndex(self: Square) u6 {
        return @intCast(@intFromEnum(self));
    }

    pub const Squares: [65]Square = .{
        .A8, .B8, .C8, .D8, .E8, .F8, .G8, .H8,
        .A7, .B7, .C7, .D7, .E7, .F7, .G7, .H7,
        .A6, .B6, .C6, .D6, .E6, .F6, .G6, .H6,
        .A5, .B5, .C5, .D5, .E5, .F5, .G5, .H5,
        .A4, .B4, .C4, .D4, .E4, .F4, .G4, .H4,
        .A3, .B3, .C3, .D3, .E3, .F3, .G3, .H3,
        .A2, .B2, .C2, .D2, .E2, .F2, .G2, .H2,
        .A1, .B1, .C1, .D1, .E1, .F1, .G1, .H1,
        .XX,
    };

    pub fn FromIndex(index: u6) !Square {
        if (index >= 64) return error.InvalidIndex;
        return Squares[index];
    }

    pub fn toString(self: Square) []const u8 {
        return switch (self) {
            .A8 => "a8", .B8 => "b8", .C8 => "c8", .D8 => "d8", .E8 => "e8", .F8 => "f8", .G8 => "g8", .H8 => "h8",
            .A7 => "a7", .B7 => "b7", .C7 => "c7", .D7 => "d7", .E7 => "e7", .F7 => "f7", .G7 => "g7", .H7 => "h7",
            .A6 => "a6", .B6 => "b6", .C6 => "c6", .D6 => "d6", .E6 => "e6", .F6 => "f6", .G6 => "g6", .H6 => "h6",
            .A5 => "a5", .B5 => "b5", .C5 => "c5", .D5 => "d5", .E5 => "e5", .F5 => "f5", .G5 => "g5", .H5 => "h5",
            .A4 => "a4", .B4 => "b4", .C4 => "c4", .D4 => "d4", .E4 => "e4", .F4 => "f4", .G4 => "g4", .H4 => "h4",
            .A3 => "a3", .B3 => "b3", .C3 => "c3", .D3 => "d3", .E3 => "e3", .F3 => "f3", .G3 => "g3", .H3 => "h3",
            .A2 => "a2", .B2 => "b2", .C2 => "c2", .D2 => "d2", .E2 => "e2", .F2 => "f2", .G2 => "g2", .H2 => "h2",
            .A1 => "a1", .B1 => "b1", .C1 => "c1", .D1 => "d1", .E1 => "e1", .F1 => "f1", .G1 => "g1", .H1 => "h1",
            .XX => "XX",
        };
    }
};
// zig fmt: on
