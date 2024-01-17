const std = @import("std");

pub const Token = union(enum) { positional: Positional, parameter: Parameter };
pub const Positional = struct { value: []const u8 };
pub const Parameter = struct { name: []const u8, value: ?[]const u8 };

pub fn tokenize(args: *ArgIterator, allocator: std.mem.Allocator) std.mem.Allocator.Error!std.ArrayList(Token) {
    var output = std.ArrayList(Token).init(allocator);

    while (args.readNext()) |arg| {
        const token: Token = switch (arg[0]) {
            '-' => switch (arg[1]) {
                '-' => parseLongParamToken(arg, args),
                else => parseShortParamToken(arg, args),
            },
            else => parsePositionalToken(arg, args),
        };

        try output.append(token);
    }

    return output;
}

fn parseLongParamToken(argument: []const u8, args: *ArgIterator) Token {
    _ = args;
    var name: []const u8 = undefined;
    var value: ?[]const u8 = undefined;

    if (std.mem.indexOf(u8, argument, "=")) |index| {
        name = argument[2..index];
        value = argument[index + 1 ..];
    } else {
        name = argument[2..];
        value = null;
    }

    return Token{ .parameter = .{ .name = name, .value = value } };
}

fn parseShortParamToken(argument: []const u8, args: *ArgIterator) Token {
    _ = args;
    _ = argument;
    return Token{ .parameter = .{ .name = "", .value = null } };
}

fn parsePositionalToken(argument: []const u8, args: *ArgIterator) Token {
    _ = args;
    _ = argument;
    return Token{ .positional = .{ .value = "" } };
}

pub const ArgIterator = struct {
    inner: ArgIterator.Type,

    index: u32 = 0,
    curr: ?[:0]const u8 = null,
    next: ?[:0]const u8 = null,

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

    pub fn readNext(self: *ArgIterator) ?[:0]const u8 {
        self.curr = if (self.next) |next| next else self._readNext();
        self.next = self._readNext();
        return self.curr;
    }

    pub fn peekNext(self: *ArgIterator) ?[:0]const u8 {
        return self.next;
    }

    fn _readNext(self: *ArgIterator) ?[:0]const u8 {
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
    try std.testing.expectEqualSentinel(u8, 0, "positional", iterator.peekNext().?);

    try std.testing.expectEqualSentinel(u8, 0, "positional", iterator.readNext().?);
    try std.testing.expectEqualSentinel(u8, 0, "--flag", iterator.peekNext().?);

    try std.testing.expectEqualSentinel(u8, 0, "--flag", iterator.readNext().?);
    try std.testing.expectEqualSentinel(u8, 0, "-s", iterator.peekNext().?);

    try std.testing.expectEqualSentinel(u8, 0, "-s", iterator.readNext().?);
    try std.testing.expect(null == iterator.peekNext());

    try std.testing.expect(null == iterator.readNext());
    try std.testing.expect(null == iterator.peekNext());
}
