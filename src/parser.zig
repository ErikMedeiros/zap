const std = @import("std");
const lexer = @import("lexer.zig");
const it = @import("iterator.zig");

pub fn parseTokens(comptime T: type, tokens: []const lexer.Token) !T {
    var config: T = undefined;

    inline for (std.meta.fields(T)) |field| {
        if (field.default_value) |dvalue| {
            const dvalue_aligned: *align(field.alignment) const anyopaque = @alignCast(dvalue);
            @field(config, field.name) = @as(*const field.type, @ptrCast(dvalue_aligned)).*;
        }
    }

    var tokens_it = it.SliceIterator(lexer.Token).init(tokens);

    while (tokens_it.iterator.next()) |token| {
        switch (token) {
            .value => {},
            .parameter => |param| try parseParameterToken(param.name, &tokens_it.iterator, &config),
            .short_chain => |chain| try parseShortChainToken(chain, &tokens_it.iterator, &config),
        }
    }

    return config;
}

fn parseParameterToken(
    parameter: []const u8,
    iterator: *it.Iterator(lexer.Token),
    config: anytype,
) !void {
    inline for (std.meta.fields(@TypeOf(config.*))) |field| {
        if (std.mem.eql(u8, field.name, parameter)) {
            if (field.type == bool) {
                @field(config.*, field.name) = true;
            } else if (iterator.peek()) |peek| {
                if (peek == .value) {
                    @field(config.*, field.name) = try fromString(field.type, iterator.next().?.value);
                }
            } else {
                return error.NoValue;
            }
        }
    }
}

fn parseShortChainToken(
    parameter: []const u8,
    iterator: *it.Iterator(lexer.Token),
    config: anytype,
) !void {
    for (0..parameter.len) |i| chain: {
        const arg = parameter[i .. i + 1];

        inline for (std.meta.fields(@TypeOf(config.*))) |field| {
            if (std.mem.eql(u8, field.name, arg)) {
                if (field.type == bool) {
                    @field(config.*, field.name) = true;
                } else if (i + 1 != parameter.len) {
                    const value = try fromString(field.type, parameter[i + 1 ..]);
                    @field(config.*, field.name) = value;
                    break :chain;
                } else if (iterator.peek()) |peek| {
                    if (peek == .value) {
                        const value = try fromString(field.type, iterator.next().?.value);
                        @field(config.*, field.name) = value;
                        break :chain;
                    } else {
                        return error.NoValue;
                    }
                } else {
                    return error.NoValue;
                }
            }
        }
    }
}

fn fromString(comptime T: type, value: []const u8) !T {
    if (T == @TypeOf(value)) {
        return value;
    }

    return switch (@typeInfo(T)) {
        .Int => std.fmt.parseInt(T, value, 10),
        .Float => std.fmt.parseFloat(T, value),
        .Optional => |op| switch (@typeInfo(op.child)) {
            .Int => @as(T, try std.fmt.parseInt(op.child, value, 10)),
            .Float => @as(T, try std.fmt.parseFloat(op.child, value)),
            else => error.IllegalConversion,
        },
        else => error.IllegalConversion,
    };
}

test parseTokens {
    const TestType = struct {
        flag: []const u8,
        long: []const u8,
        a: u32,
        b: u8,
        c: bool,
        d: bool,
        e: ?u8 = null,
        f: bool,
        g: u16,
    };

    var strs = it.SliceIterator([:0]const u8).init(&.{ "--flag=value", "--long", "long_flag", "-a132", "-b", "2", "-cde3", "-fg", "4" });

    const tokens = try lexer.tokenize(&strs.iterator, std.testing.allocator);
    defer tokens.deinit();

    const config = try parseTokens(TestType, tokens.items);

    try std.testing.expectEqualStrings("value", config.flag);
    try std.testing.expectEqualStrings("long_flag", config.long);

    try std.testing.expect(2 == config.b);
    try std.testing.expect(3 == config.e);
    try std.testing.expect(4 == config.g);
    try std.testing.expect(132 == config.a);

    try std.testing.expect(config.c);
    try std.testing.expect(config.d);
    try std.testing.expect(config.f);
}
