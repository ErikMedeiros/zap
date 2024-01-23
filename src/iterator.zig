const std = @import("std");

pub fn Iterator(comptime T: type) type {
    return struct {
        nextFn: *const fn (*Iterator(T)) ?T,
        peekFn: *const fn (*Iterator(T)) ?T,

        pub fn next(it: *Iterator(T)) ?T {
            return it.nextFn(it);
        }

        pub fn peek(it: *Iterator(T)) ?T {
            return it.peekFn(it);
        }
    };
}

pub const ArgIterator = struct {
    args: std.process.ArgIterator,
    iterator: Iterator([:0]const u8),
    curr: ValueState = .undefined,
    next: ValueState = .undefined,

    const ValueState = union(enum) { undefined, value: ?[:0]const u8 };

    pub fn init(args: *std.process.ArgIterator) ArgIterator {
        return ArgIterator{ .args = args.*, .iterator = .{ .nextFn = readNext, .peekFn = peekNext } };
    }

    fn readNext(it: *Iterator([:0]const u8)) ?[:0]const u8 {
        const self = @fieldParentPtr(ArgIterator, "iterator", it);

        if (self.next == ValueState.value and self.next.value == null) {
            return null;
        }

        switch (self.curr) {
            .undefined => {
                self.curr = ValueState{ .value = self.args.next() };
                self.next = ValueState{ .value = self.args.next() };
            },
            .value => {
                self.curr.value = self.next.value;
                self.next.value = self.args.next();
            },
        }

        return self.curr.value;
    }

    fn peekNext(it: *Iterator([:0]const u8)) ?[:0]const u8 {
        const self = @fieldParentPtr(ArgIterator, "iterator", it);

        return switch (self.next) {
            .undefined => null,
            .value => |v| v,
        };
    }
};

pub const StringIterator = struct {
    text: []const [:0]const u8,
    iterator: Iterator([:0]const u8),
    index: ?usize = null,

    pub fn init(text: []const [:0]const u8) StringIterator {
        return StringIterator{ .text = text, .iterator = .{ .nextFn = readNext, .peekFn = peekNext } };
    }

    fn readNext(it: *Iterator([:0]const u8)) ?[:0]const u8 {
        const self = @fieldParentPtr(StringIterator, "iterator", it);
        const index = self.index orelse 0;
        const next = if (index >= self.text.len) null else self.text[index];
        self.index = index + 1;
        return next;
    }

    fn peekNext(it: *Iterator([:0]const u8)) ?[:0]const u8 {
        const self = @fieldParentPtr(StringIterator, "iterator", it);
        const index = (self.index orelse 0) + 1;
        return if (index >= self.text.len) null else self.text[index];
    }
};
