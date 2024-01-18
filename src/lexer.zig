const std = @import("std");

pub const Token = union(enum) {
    value: []const u8,
    parameter: struct { name: []const u8 },
};

pub fn tokenize(args: *ArgIterator, allocator: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(Token) {
    var output = std.ArrayList(Token).init(allocator);

    while (args.readNext()) |arg| {
        const tokens: []const Token = switch (arg[0]) {
            '-' => switch (arg[1]) {
                '-' => try parseLongParamToken(arg[2..]),
                else => try parseShortParamToken(arg[1..]),
            },
            else => &.{Token{ .value = arg }},
        };

        for (tokens) |token| {
            try output.append(token);
        }
    }

    return output;
}

fn parseLongParamToken(argument: []const u8) std.mem.Allocator.Error![]const Token {
    var tokens = std.ArrayList(Token).init(std.heap.page_allocator);

    if (std.mem.indexOf(u8, argument, "=")) |index| {
        try tokens.append(Token{ .parameter = .{ .name = argument[0..index] } });
        try tokens.append(Token{ .value = argument[index + 1 ..] });
    } else {
        try tokens.append(Token{ .parameter = .{ .name = argument } });
    }

    return tokens.toOwnedSlice();
}

fn parseShortParamToken(argument: []const u8) std.mem.Allocator.Error![]const Token {
    var tokens: std.ArrayList(Token) = undefined;

    if (std.mem.indexOf(u8, argument, "=")) |index| {
        tokens = try std.ArrayList(Token).initCapacity(std.heap.page_allocator, index + 1);

        for (0..index) |i| {
            try tokens.append(Token{ .parameter = .{ .name = argument[i .. i + 1] } });
        }
        try tokens.append(Token{ .value = argument[index + 1 ..] });
    } else {
        tokens = try std.ArrayList(Token).initCapacity(std.heap.page_allocator, argument.len);

        for (0..argument.len) |i| {
            try tokens.append(Token{ .parameter = .{ .name = argument[i .. i + 1] } });
        }
    }

    return tokens.toOwnedSlice();
}

pub const ArgIterator = struct {
    inner: ArgIterator.Type,

    index: u32 = 0,
    curr: ?[:0]const u8 = null,

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
