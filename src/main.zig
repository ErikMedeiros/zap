const std = @import("std");
const lexer = @import("lexer.zig");
const ArgIterator = @import("iterator.zig").ArgIterator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    var args_it = ArgIterator.init(&args);

    const tokens = try lexer.tokenize(&args_it.iterator, allocator);

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
    std.testing.refAllDecls(@This());
}
