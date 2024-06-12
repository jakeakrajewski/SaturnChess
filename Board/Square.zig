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

    pub fn fromIndex(index: u6) !Square {
        if (index >= 64) return error.InvalidIndex;
        return Squares[index];
    }

    pub fn toString(self: Square) []const u8 {
        return switch (self) {
            .A8 => "A8", .B8 => "B8", .C8 => "C8", .D8 => "D8", .E8 => "E8", .F8 => "F8", .G8 => "G8", .H8 => "H8",
            .A7 => "A7", .B7 => "B7", .C7 => "C7", .D7 => "D7", .E7 => "E7", .F7 => "F7", .G7 => "G7", .H7 => "H7",
            .A6 => "A6", .B6 => "B6", .C6 => "C6", .D6 => "D6", .E6 => "E6", .F6 => "F6", .G6 => "G6", .H6 => "H6",
            .A5 => "A5", .B5 => "B5", .C5 => "C5", .D5 => "D5", .E5 => "E5", .F5 => "F5", .G5 => "G5", .H5 => "H5",
            .A4 => "A4", .B4 => "B4", .C4 => "C4", .D4 => "D4", .E4 => "E4", .F4 => "F4", .G4 => "G4", .H4 => "H4",
            .A3 => "A3", .B3 => "B3", .C3 => "C3", .D3 => "D3", .E3 => "E3", .F3 => "F3", .G3 => "G3", .H3 => "H3",
            .A2 => "A2", .B2 => "B2", .C2 => "C2", .D2 => "D2", .E2 => "E2", .F2 => "F2", .G2 => "G2", .H2 => "H2",
            .A1 => "A1", .B1 => "B1", .C1 => "C1", .D1 => "D1", .E1 => "E1", .F1 => "F1", .G1 => "G1", .H1 => "H1",
            .XX => "XX",
        };
    }
};
// zig fmt: on
