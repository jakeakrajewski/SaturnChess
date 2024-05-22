const std = @import("std");
const brd = @import("Game/Board.zig");

pub fn main() void {
    const allocator = std.heap.page_allocator;

    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();
    var stderr = std.io.getStdErr().writer();

    var board: brd.Board = undefined;
    while (true) {
        const line = try readLine(allocator, &stdin);
        defer allocator.free(line);

        if (std.mem.eql(u8, line, "uci")) {
            try stdout.print("id name Saturn\n", .{});
            try stdout.print("id author Jake Krajewski\n", .{});
            try stdout.print("uciok\n", .{});
        } else if (std.mem.eql(u8, line, "isready")) {
            try stdout.print("readyok\n", .{});
        } else if (std.mem.eql(u8, line, "quit")) {
            break;
        } else if (std.mem.eql(u8, line, "ucinewgame")) {
            // Handle new game setup here.
            board = brd.newBoard();
        } else if (std.mem.startsWith(u8, line, "position")) {
            // Parse and handle the position command.
        } else if (std.mem.startsWith(u8, line, "go")) {
            // Parse and handle the go command to start search.
        } else {
            try stderr.print("Unknown command: {}\n", .{line});
        }
    }
}

fn readLine(allocator: *std.mem.Allocator, stdin: *std.io.BufferedReader(std.io.Reader)) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);

    while (true) {
        const byte: u8 = try stdin.readByte();
        if (byte == '\n') break;
        try buffer.append(byte);
    }

    return buffer.toOwnedSlice();
}
