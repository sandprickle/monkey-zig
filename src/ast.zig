const std = @import("std");
const Token = @import("token.zig").Token;

/// One of several types of statements
pub const Statement = union(enum) {
    let: LetStatement,
    _return: ReturnStatement,

    pub fn tokenLiteral(self: Statement) []const u8 {
        return switch (self) {
            .let => |let_stmt| let_stmt.token.literal,
            ._return => |return_stmt| return_stmt.token.literal,
        };
    }
};

/// A statement that assigns a value to an identifier
pub const LetStatement = struct {
    token: Token,
    ident: Identifier,
    value: ?Expression,
};

/// A statement that returns a value
pub const ReturnStatement = struct {
    token: Token,
    value: ?Expression,
};

const Expression = struct {};

pub const Identifier = struct {
    token: Token,
    value: []const u8,
};

/// A list of statements
pub const Program = struct {
    statements: std.ArrayList(Statement),
};
