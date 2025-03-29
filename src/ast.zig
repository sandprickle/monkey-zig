const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const Statement = union(enum) {
    const Self = @This();
    let: Let,
    _return: Return,
    expression: Expr,

    /// A statement that assigns a value to an identifier
    pub const Let = struct {
        token: Token,
        ident: Identifier,
        value: ?Expression,
    };

    /// A statement that returns a value
    pub const Return = struct {
        token: Token,
        value: ?Expression,
    };

    pub const Expr = struct {
        token: Token,
        expression: Expression,
    };

    pub fn tokenLiteral(self: Self) []const u8 {
        return switch (self) {
            .let => |let_stmt| let_stmt.token.literal,
            ._return => |return_stmt| return_stmt.token.literal,
            .expression => |expr_stmt| expr_stmt.token.literal,
        };
    }
    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .let => |let_stmt| {
                try writer.print("{s} {s} = ", .{ let_stmt.token.literal, let_stmt.ident.value });
                if (let_stmt.value) |value| {
                    try writer.print("{s}", .{value});
                }
                try writer.print(";", .{});
            },
            ._return => |return_stmt| {
                try writer.print("{s} ", .{return_stmt.token.literal});
                if (return_stmt.value) |value| {
                    try writer.print("{s}", .{value});
                }
                try writer.print(";", .{});
            },
            .expression => |expr_stmt| try expr_stmt.expression.format(
                fmt,
                options,
                writer,
            ),
        }
    }
};

pub const Expression = union(enum) {
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
