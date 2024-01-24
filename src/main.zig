const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const ArgIterator = @import("iterator.zig").ArgIterator;

const Config = struct {
    @"max-count": ?u32 = null,
    path: []const u8 = "/",
    port: u16 = 433,
    @"case-insensitive": bool = false,
    pi: f32 = std.math.pi,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    var args_it = ArgIterator.init(&args);

    const tokens = try lexer.tokenize(&args_it.iterator, allocator);
    const config = try parser.parseTokens(Config, tokens.items);

    const writter = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(writter);
    const stdout = bw.writer();

    try stdout.print("max-count: ?u32 = {?d}", .{config.@"max-count"});
    try stdout.print("\npath: []const u8 = {s}", .{config.path});
    try stdout.print("\nport: u16 = {d}", .{config.port});
    try stdout.print("\ncase-insensitive: bool = {s}", .{if (config.@"case-insensitive") "true" else "false"});
    try stdout.print("\npi: f32 = {d}\n", .{config.pi});

    try bw.flush();
}

test {
    std.testing.refAllDecls(@This());
}
