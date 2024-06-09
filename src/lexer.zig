const token = @import("token.zig");
const std = @import("std");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const Token = token.Token;
const TokenType = token.TokenType;

pub const Lexer = struct {
    const Self = @This();

    input: []const u8,
    pos: usize,
    read_pos: usize,
    ch: u8,

    pub fn nextToken(l: *Self) ?Token {
        var tok: Token = undefined;
        l.munchWhitespace();
        switch (l.ch) {
            '=' => {
                if (l.peekChar() == '=') {
                    tok = token.new(TokenType.eq, "==");
                    l.readChar();
                } else {
                    tok = token.new(TokenType.assign, "=");
                }
            },
            '+' => tok = token.new(TokenType.plus, "+"),
            '-' => tok = token.new(TokenType.minus, "-"),
            '*' => tok = token.new(TokenType.asterisk, "*"),
            '/' => tok = token.new(TokenType.slash, "/"),
            '>' => tok = token.new(TokenType.gt, ">"),
            '<' => tok = token.new(TokenType.lt, "<"),
            '!' => {
                if (l.peekChar() == '=') {
                    tok = token.new(TokenType.not_eq, "!=");
                    l.readChar();
                } else {
                    tok = token.new(TokenType.bang, "!");
                }
            },
            ',' => tok = token.new(TokenType.comma, ","),
            ';' => tok = token.new(TokenType.semicolon, ";"),
            '(' => tok = token.new(TokenType.l_paren, "("),
            ')' => tok = token.new(TokenType.r_paren, ")"),
            '{' => tok = token.new(TokenType.l_brace, "{"),
            '}' => tok = token.new(TokenType.r_brace, "}"),
            0 => {
                return null;
            },
            else => {
                if (isLetter(l.ch)) {
                    tok.literal = l.readWord();
                    tok.type = token.keywordOrIdent(tok.literal);
                    return tok;
                } else if (isDigit(l.ch)) {
                    tok = token.new(TokenType.int, l.readInt());
                    return tok;
                } else {
                    tok = token.new(TokenType.illegal, &[1]u8{l.ch});
                }
            },
        }
        l.readChar();
        return tok;
    }

    fn readChar(l: *Self) void {
        if (l.read_pos >= l.input.len) {
            l.ch = 0;
        } else {
            l.ch = l.input[l.read_pos];
        }

        l.pos = l.read_pos;
        l.read_pos += 1;
    }

    fn peekChar(l: *Self) u8 {
        if (l.read_pos >= l.input.len) {
            return 0;
        } else {
            return l.input[l.read_pos];
        }
    }

    /// Read an identifier or keyword
    fn readWord(l: *Self) []const u8 {
        const start_pos = l.pos;
        while (isLetter(l.ch)) {
            l.readChar();
        }
        return l.input[start_pos..l.pos];
    }

    /// Read an integer
    fn readInt(l: *Self) []const u8 {
        const start_pos = l.pos;
        while (isDigit(l.ch)) {
            l.readChar();
        }
        return l.input[start_pos..l.pos];
    }

    fn munchWhitespace(l: *Self) void {
        while (l.ch == ' ' or l.ch == '\t' or l.ch == '\n' or l.ch == '\r') {
            l.readChar();
        }
    }
};

pub fn new(input: []const u8) Lexer {
    var l = Lexer{
        .input = input,
        .pos = 0,
        .read_pos = 0,
        .ch = 0,
    };
    l.readChar();
    return l;
}

test new {
    const lex = new("let foo = 80;");

    try expectEqual(Lexer{
        .input = "let foo = 80;",
        .pos = 0,
        .read_pos = 1,
        .ch = 'l',
    }, lex);
}

fn isLetter(ch: u8) bool {
    return ('a' <= ch and ch <= 'z') or ('A' <= ch and ch <= 'Z') or ch == '_';
}

fn isDigit(ch: u8) bool {
    return '0' <= ch and ch <= '9';
}

test "Lexer.readChar" {
    var lex = Lexer{
        .input = "let foo = 80;",
        .pos = 0,
        .read_pos = 0,
        .ch = 0,
    };

    lex.readChar();

    try expectEqual(Lexer{
        .input = "let foo = 80;",
        .pos = 0,
        .read_pos = 1,
        .ch = 'l',
    }, lex);
}

test "Lexer.munchWhitespace" {
    const input = "     return 7;";

    var lex = new(input);
    lex.munchWhitespace();

    try expectEqual(Lexer{
        .input = input,
        .pos = 5,
        .read_pos = 6,
        .ch = 'r',
    }, lex);
}

test "Lexer.nextToken" {
    const input_1 = "4";
    var lex_1 = new(input_1);
    try expectEqual(token.new(TokenType.int, "4"), lex_1.nextToken());

    const input_2 = "let foo = 10;";
    var lex_2 = new(input_2);

    const token_1 = lex_2.nextToken();
    try expect(token_1.type == TokenType.let);
    try expectEqualStrings("let", token_1.literal);

    const token_2 = lex_2.nextToken();
    try expect(token_2.type == TokenType.ident);
    try expectEqualStrings("foo", token_2.literal);

    const token_3 = lex_2.nextToken();
    try expect(token_3.type == TokenType.assign);
    try expectEqualStrings("=", token_3.literal);

    const token_4 = lex_2.nextToken();
    try expect(token_4.type == TokenType.int);
    try expectEqualStrings("10", token_4.literal);

    const token_5 = lex_2.nextToken();
    try expect(token_5.type == TokenType.semicolon);
    try expectEqualStrings(";", token_5.literal);
}

test Lexer {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
        \\
        \\!-/*5;
        \\5 < 10 > 5;
        \\
        \\if (5 < 10) {
        \\  return true;
        \\} else {
        \\  return false;
        \\}
        \\
        \\10 == 10;
        \\10 != 9;
    ;

    const expectations = [_]Token{
        token.new(TokenType.let, "let"),
        token.new(TokenType.ident, "five"),
        token.new(TokenType.assign, "="),
        token.new(TokenType.int, "5"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.let, "let"),
        token.new(TokenType.ident, "ten"),
        token.new(TokenType.assign, "="),
        token.new(TokenType.int, "10"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.let, "let"),
        token.new(TokenType.ident, "add"),
        token.new(TokenType.assign, "="),
        token.new(TokenType.function, "fn"),
        token.new(TokenType.l_paren, "("),
        token.new(TokenType.ident, "x"),
        token.new(TokenType.comma, ","),
        token.new(TokenType.ident, "y"),
        token.new(TokenType.r_paren, ")"),
        token.new(TokenType.l_brace, "{"),

        token.new(TokenType.ident, "x"),
        token.new(TokenType.plus, "+"),
        token.new(TokenType.ident, "y"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.r_brace, "}"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.let, "let"),
        token.new(TokenType.ident, "result"),
        token.new(TokenType.assign, "="),
        token.new(TokenType.ident, "add"),
        token.new(TokenType.l_paren, "("),
        token.new(TokenType.ident, "five"),
        token.new(TokenType.comma, ","),
        token.new(TokenType.ident, "ten"),
        token.new(TokenType.r_paren, ")"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.bang, "!"),
        token.new(TokenType.minus, "-"),
        token.new(TokenType.slash, "/"),
        token.new(TokenType.asterisk, "*"),
        token.new(TokenType.int, "5"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.int, "5"),
        token.new(TokenType.lt, "<"),
        token.new(TokenType.int, "10"),
        token.new(TokenType.gt, ">"),
        token.new(TokenType.int, "5"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType._if, "if"),
        token.new(TokenType.l_paren, "("),
        token.new(TokenType.int, "5"),
        token.new(TokenType.lt, "<"),
        token.new(TokenType.int, "10"),
        token.new(TokenType.r_paren, ")"),
        token.new(TokenType.l_brace, "{"),
        token.new(TokenType._return, "return"),
        token.new(TokenType._true, "true"),
        token.new(TokenType.semicolon, ";"),
        token.new(TokenType.r_brace, "}"),
        token.new(TokenType._else, "else"),
        token.new(TokenType.l_brace, "{"),
        token.new(TokenType._return, "return"),
        token.new(TokenType._false, "false"),
        token.new(TokenType.semicolon, ";"),
        token.new(TokenType.r_brace, "}"),

        token.new(TokenType.int, "10"),
        token.new(TokenType.eq, "=="),
        token.new(TokenType.int, "10"),
        token.new(TokenType.semicolon, ";"),

        token.new(TokenType.int, "10"),
        token.new(TokenType.not_eq, "!="),
        token.new(TokenType.int, "9"),
        token.new(TokenType.semicolon, ";"),
    };

    var lexer = new(input);

    for (expectations) |expected_token| {
        const current_token = lexer.nextToken();
        try expectEqual(expected_token.type, current_token.type);
        try expectEqualStrings(
            expected_token.literal,
            current_token.literal,
        );
    }
}
