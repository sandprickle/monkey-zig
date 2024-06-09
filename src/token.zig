const std = @import("std");
const expectEqual = std.testing.expectEqual;

pub const Token = struct {
    const Self = @This();

    type: TokenType,
    literal: []const u8,

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

pub fn new(token_type: TokenType, literal: []const u8) Token {
    const t = Token{
        .type = token_type,
        .literal = literal,
    };

    return t;
}

test new {
    try expectEqual(
        Token{ .type = .ident, .literal = "foo" },
        new(TokenType.ident, "foo"),
    );
}

pub const TokenType = enum {
    illegal,

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
};

/// Valid Monkey keywords
const keywords = [_]Token{
    Token{ .literal = "fn", .type = .function },
    Token{ .literal = "let", .type = .let },
    Token{ .literal = "true", .type = ._true },
    Token{ .literal = "false", .type = ._false },
    Token{ .literal = "if", .type = ._if },
    Token{ .literal = "else", .type = ._else },
    Token{ .literal = "return", .type = ._return },
};

/// Returns a keyword token if `str` is a valid keyword.
/// Otherwise, returns an identifier token.
pub fn keywordOrIdent(str: []const u8) TokenType {
    for (keywords) |keyword| {
        if (std.mem.eql(u8, str, keyword.literal)) return keyword.type;
    }

    return .ident;
}

test keywordOrIdent {
    try expectEqual(keywordOrIdent("let"), .let);
    try expectEqual(keywordOrIdent("foo"), .ident);
}
