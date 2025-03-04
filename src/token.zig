const std = @import("std");
const expectEqual = std.testing.expectEqual;
const assert = std.debug.assert;

pub const Token = struct {
    const Self = @This();

    type: TokenType,
    literal: []const u8,

    pub fn new(comptime token_type: TokenType, literal: []const u8) Self {
        // assert(!std.mem.eql(u8, literal, ""));

        const predefined_literal = token_type.literal();
        if (predefined_literal) |lit| {
            assert(std.mem.eql(u8, literal, lit));
        }

        return Self{
            .type = token_type,
            .literal = literal,
        };
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const t_type = switch (self.type) {
            .illegal => "illegal ",
            .eof => "EOF ",
            .ident => "ident   ",
            .int => "int     ",
            .assign => "assign  ",
            .plus => "plus    ",
            .minus => "minus   ",
            .asterisk => "asterisk",
            .slash => "slash  ",
            .bang => "bang    ",
            .gt => "gt      ",
            .lt => "lt      ",
            .eq => "eq      ",
            .not_eq => "not_eq  ",
            .comma => "comma   ",
            .semicolon => "semicolon",
            .l_paren => "l_paren",
            .r_paren => "r_paren ",
            .l_brace => "l_brace",
            .r_brace => "r_brace",
            .function => "function",
            .let => "let     ",
            ._true => "true    ",
            ._false => "false   ",
            ._if => "if      ",
            ._else => "else    ",
            ._return => "return  ",
        };

        try writer.print(
            "| {s}\t{c}{s}{c}",
            .{ t_type, '"', self.literal, '"' },
        );
    }
};

test "Token.new" {
    try expectEqual(
        Token{ .type = .ident, .literal = "foo" },
        Token.new(TokenType.ident, "foo"),
    );

    try expectEqual(
        Token{ .type = .lt, .literal = "<" },
        Token.new(.lt, "<"),
    );
}

pub const TokenType = enum {
    const Self = @This();

    illegal,
    eof,

    // Idenetifiers + Literals
    ident,
    int,

    // Operators
    assign,
    plus,
    minus,
    asterisk,
    slash,
    bang,
    gt,
    lt,
    eq,
    not_eq,

    // Delimiters
    comma,
    semicolon,
    l_paren,
    r_paren,
    l_brace,
    r_brace,

    // Keywords
    function,
    let,
    _true,
    _false,
    _if,
    _else,
    _return,

    fn literal(self: Self) ?[]const u8 {
        const result = switch (self) {
            TokenType.eof => "",
            TokenType.assign => "=",
            TokenType.plus => "+",
            TokenType.minus => "-",
            TokenType.asterisk => "*",
            TokenType.slash => "/",
            TokenType.bang => "!",
            TokenType.gt => ">",
            TokenType.lt => "<",
            TokenType.eq => "==",
            TokenType.not_eq => "!=",
            TokenType.comma => ",",
            TokenType.semicolon => ";",
            TokenType.l_paren => "(",
            TokenType.r_paren => ")",
            TokenType.l_brace => "{",
            TokenType.r_brace => "}",
            TokenType.function => "fn",
            TokenType.let => "let",
            TokenType._true => "true",
            TokenType._false => "false",
            TokenType._if => "if",
            TokenType._else => "else",
            TokenType._return => "return",
            else => null,
        };

        return result;
    }
};

/// Returns a keyword token if `str` is a valid keyword.
/// Otherwise, returns an identifier token.
pub fn keywordOrIdent(str: []const u8) TokenType {
    const keywords = [_]Token{
        Token{ .literal = "fn", .type = .function },
        Token{ .literal = "let", .type = .let },
        Token{ .literal = "true", .type = ._true },
        Token{ .literal = "false", .type = ._false },
        Token{ .literal = "if", .type = ._if },
        Token{ .literal = "else", .type = ._else },
        Token{ .literal = "return", .type = ._return },
    };

    for (keywords) |keyword| {
        if (std.mem.eql(u8, str, keyword.literal)) return keyword.type;
    }

    return .ident;
}

test keywordOrIdent {
    try expectEqual(keywordOrIdent("let"), .let);
    try expectEqual(keywordOrIdent("foo"), .ident);
}
