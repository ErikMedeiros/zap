const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    var iterator = lexer.ArgIterator.initStd(&args);

    const tokens = try lexer.tokenize(&iterator, allocator);

    const writter = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(writter);
    const stdout = bw.writer();

    for (tokens.items) |token| {
        try switch (token) {
            .parameter => |p| stdout.print("[PARAMETER]: {s}\n", .{p.name}),
            .value => |v| stdout.print("[VALUE]: {s}\n", .{v}),
            .short_or_value => |sov| stdout.print("[SHORT_OR_VALUE]: {s}\n", .{sov}),
        };
    }

    try bw.flush();
}

test {
    _ = lexer;
}
