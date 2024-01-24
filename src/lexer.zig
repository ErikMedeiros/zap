const std = @import("std");
const it = @import("iterator.zig");

pub const Token = union(enum) {
    value: []const u8,
    short_or_value: []const u8,
    parameter: struct { name: []const u8 },
};

pub fn tokenize(args: *it.Iterator([:0]const u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);

    while (args.next()) |arg| {
        try switch (arg[0]) {
            '-' => switch (arg[1]) {
                '-' => parseLongParam(arg[2..], &tokens),
                else => parseShortParam(arg[1..], &tokens),
            },
            else => tokens.append(Token{ .value = arg }),
        };
    }

    return tokens;
}

fn parseLongParam(argument: []const u8, tokens: *std.ArrayList(Token)) std.mem.Allocator.Error!void {
    if (std.mem.indexOf(u8, argument, "=")) |index| {
        try tokens.appendSlice(&.{
            Token{ .parameter = .{ .name = argument[0..index] } },
            Token{ .value = argument[index + 1 ..] },
        });
    } else {
        try tokens.append(Token{ .parameter = .{ .name = argument } });
    }
}

fn parseShortParam(argument: []const u8, tokens: *std.ArrayList(Token)) std.mem.Allocator.Error!void {
    if (argument.len == 1) {
        try tokens.append(Token{ .parameter = .{ .name = argument[0..1] } });
    } else {
        for (0..argument.len - 1) |i| {
            try tokens.append(Token{ .parameter = .{ .name = argument[i .. i + 1] } });
        }
        try tokens.append(Token{ .short_or_value = argument[argument.len - 1 ..] });
    }
}

test tokenize {
    var strs = it.SliceIterator([:0]const u8).init(&.{ "--flag=value", "--long", "long_flag", "-a1", "-b", "2", "-cde3", "-fg", "4" });
    const tokens = try tokenize(&strs.iterator, std.testing.allocator);
    defer tokens.deinit();

    try std.testing.expectEqualStrings("flag", tokens.items[0].parameter.name);
    try std.testing.expectEqualStrings("value", tokens.items[1].value);

    try std.testing.expectEqualStrings("long", tokens.items[2].parameter.name);
    try std.testing.expectEqualStrings("long_flag", tokens.items[3].value);

    try std.testing.expectEqualStrings("a", tokens.items[4].parameter.name);
    try std.testing.expectEqualStrings("1", tokens.items[5].short_or_value);

    try std.testing.expectEqualStrings("b", tokens.items[6].parameter.name);
    try std.testing.expectEqualStrings("2", tokens.items[7].value);

    try std.testing.expectEqualStrings("c", tokens.items[8].parameter.name);
    try std.testing.expectEqualStrings("d", tokens.items[9].parameter.name);
    try std.testing.expectEqualStrings("e", tokens.items[10].parameter.name);
    try std.testing.expectEqualStrings("3", tokens.items[11].short_or_value);

    try std.testing.expectEqualStrings("f", tokens.items[12].parameter.name);
    try std.testing.expectEqualStrings("g", tokens.items[13].short_or_value);
    try std.testing.expectEqualStrings("4", tokens.items[14].value);
}
