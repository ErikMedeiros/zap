const std = @import("std");

pub const Token = union(enum) {
    value: []const u8,
    short_or_value: []const u8,
    parameter: struct { name: []const u8 },
};

pub fn tokenize(args: *ArgIterator, allocator: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);

    while (args.readNext()) |arg| {
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

pub const ArgIterator = struct {
    inner: ArgIterator.Type,
    index: u32 = 0,

    pub const Type = union(enum) {
        std: std.process.ArgIterator,
        string: []const [:0]const u8,
    };

    pub fn initStd(args: *std.process.ArgIterator) ArgIterator {
        return ArgIterator{ .inner = .{ .std = args.* } };
    }

    pub fn initString(args: []const [:0]const u8) ArgIterator {
        return ArgIterator{ .inner = .{ .string = args } };
    }

    fn readNext(self: *ArgIterator) ?[:0]const u8 {
        const next = switch (self.inner) {
            .std => |*args| args.next(),
            .string => |arr| if (self.index >= arr.len) null else arr[self.index],
        };

        self.index += 1;
        return next;
    }
};

test ArgIterator {
    var iterator = ArgIterator.initString(&.{ "path/to/bin", "positional", "--flag", "-s" });

    try std.testing.expectEqualSentinel(u8, 0, "path/to/bin", iterator.readNext().?);
    try std.testing.expectEqualSentinel(u8, 0, "positional", iterator.readNext().?);
    try std.testing.expectEqualSentinel(u8, 0, "--flag", iterator.readNext().?);
    try std.testing.expectEqualSentinel(u8, 0, "-s", iterator.readNext().?);
    try std.testing.expect(null == iterator.readNext());
}

test tokenize {
    var iterator = ArgIterator.initString(&.{ "--flag=value", "--long", "long_flag", "-a1", "-b", "2", "-cde3", "-fg", "4" });
    const tokens = try tokenize(&iterator, std.testing.allocator);
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
