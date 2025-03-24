const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Statement = union(enum) {
    let: LetStatement,
    _return: ReturnStatement,
    expression: ExpressionStatement,

    pub fn tokenLiteral(self: Statement) []const u8 {
        return switch (self) {
            .let => |let_stmt| let_stmt.token.literal,
            ._return => |return_stmt| return_stmt.token.literal,
            .expression => |expr_stmt| expr_stmt.token.literal,
        };
    }
    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .let => |let_stmt| try let_stmt.format(fmt, options, writer),
            ._return => |return_stmt| try return_stmt.format(fmt, options, writer),
            .expression => |expr_stmt| try expr_stmt.format(fmt, options, writer),
        }
    }
};

/// A statement that assigns a value to an identifier
pub const LetStatement = struct {
    token: Token,
    ident: Identifier,
    value: ?Expression,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s} {s} = ", .{ self.token.literal, self.ident.value });
        if (self.value) |value| {
            try writer.print("{s}", .{value});
        }
        try writer.print(";", .{});
    }
};

/// A statement that returns a value
pub const ReturnStatement = struct {
    token: Token,
    value: ?Expression,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s} ", .{self.token.literal});
        if (self.value) |value| {
            try writer.print("{s}", .{value});
        }
        try writer.print(";", .{});
    }
};

pub const ExpressionStatement = struct {
    token: Token,
    expression: Expression,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.expression.format(fmt, options, writer);
    }
};

const Expression = union(enum) {
    ident: Identifier,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .ident => |ident| {
                try ident.format(fmt, options, writer);
            },
        }
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{self.value});
    }
};

/// A list of statements
pub const Program = struct {
    const Self = @This();

    statements: std.ArrayList(Statement),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .statements = std.ArrayList(Statement).init(allocator),
        };
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        for (self.statements.items) |stmt| {
            try writer.print("{s}\n", .{stmt});
        }
    }
};

test "AST Formatting" {
    var program = Program.init(std.testing.allocator);
    defer program.statements.deinit();

    try program.statements.append(.{ .let = .{
        .token = Token.new(.let, "let"),
        .ident = .{
            .token = Token.new(.ident, "myVar"),
            .value = "myVar",
        },
        .value = .{ .ident = .{
            .token = Token.new(.ident, "anotherVar"),
            .value = "anotherVar",
        } },
    } });

    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();

    try std.fmt.format(output.writer(), "{}", .{program});

    try std.testing.expectEqualStrings(
        "let myVar = anotherVar;\n",
        output.items,
    );
}
