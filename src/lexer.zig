const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

pub const Lexer = struct {
    const Self = @This();

    input: []const u8,
    pos: usize,
    read_pos: usize,
    ch: u8,

    pub fn init(input: []const u8) Self {
        var lexer = Self{
            .input = input,
            .pos = 0,
            .read_pos = 0,
            .ch = 0,
        };
        lexer.readChar();
        return lexer;
    }

    pub fn nextToken(l: *Self) Token {
        var tok: Token = undefined;
        l.munchWhitespace();
        switch (l.ch) {
            '=' => {
                if (l.peekChar() == '=') {
                    tok = Token.new(.eq, "==");
                    l.readChar();
                } else {
                    tok = Token.new(.assign, "=");
                }
            },
            '+' => tok = Token.new(.plus, "+"),
            '-' => tok = Token.new(.minus, "-"),
            '*' => tok = Token.new(.asterisk, "*"),
            '/' => tok = Token.new(.slash, "/"),
            '>' => tok = Token.new(.gt, ">"),
            '<' => tok = Token.new(.lt, "<"),
            '!' => {
                if (l.peekChar() == '=') {
                    tok = Token.new(.not_eq, "!=");
                    l.readChar();
                } else {
                    tok = Token.new(.bang, "!");
                }
            },
            ',' => tok = Token.new(.comma, ","),
            ';' => tok = Token.new(.semicolon, ";"),
            '(' => tok = Token.new(.l_paren, "("),
            ')' => tok = Token.new(.r_paren, ")"),
            '{' => tok = Token.new(.l_brace, "{"),
            '}' => tok = Token.new(.r_brace, "}"),
            0 => tok = Token.new(.eof, ""),
            else => {
                if (isLetter(l.ch)) {
                    tok.literal = l.readWord();
                    tok.type = token.keywordOrIdent(tok.literal);
                    return tok;
                } else if (isDigit(l.ch)) {
                    tok = Token.new(.int, l.readInt());
                    return tok;
                } else {
                    tok = Token.new(.illegal, &[1]u8{l.ch});
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

test "Lexer.new" {
    const lex = Lexer.init("let foo = 80;");

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

    var lex = Lexer.init(input);
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
    var lex_1 = Lexer.init(input_1);
    try expectEqual(Token.new(.int, "4"), lex_1.nextToken());

    const input_2 = "let foo = 10;";
    var lex_2 = Lexer.init(input_2);

    const token_1 = lex_2.nextToken();
    try expect(token_1.type == .let);
    try expectEqualStrings("let", token_1.literal);

    const token_2 = lex_2.nextToken();
    try expect(token_2.type == .ident);
    try expectEqualStrings("foo", token_2.literal);

    const token_3 = lex_2.nextToken();
    try expect(token_3.type == .assign);
    try expectEqualStrings("=", token_3.literal);

    const token_4 = lex_2.nextToken();
    try expect(token_4.type == .int);
    try expectEqualStrings("10", token_4.literal);

    const token_5 = lex_2.nextToken();
    try expect(token_5.type == .semicolon);
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
        \\@
    ;

    const expectations = [_]Token{
        Token.new(.let, "let"),
        Token.new(.ident, "five"),
        Token.new(.assign, "="),
        Token.new(.int, "5"),
        Token.new(.semicolon, ";"),

        Token.new(.let, "let"),
        Token.new(.ident, "ten"),
        Token.new(.assign, "="),
        Token.new(.int, "10"),
        Token.new(.semicolon, ";"),

        Token.new(.let, "let"),
        Token.new(.ident, "add"),
        Token.new(.assign, "="),
        Token.new(.function, "fn"),
        Token.new(.l_paren, "("),
        Token.new(.ident, "x"),
        Token.new(.comma, ","),
        Token.new(.ident, "y"),
        Token.new(.r_paren, ")"),
        Token.new(.l_brace, "{"),

        Token.new(.ident, "x"),
        Token.new(.plus, "+"),
        Token.new(.ident, "y"),
        Token.new(.semicolon, ";"),

        Token.new(.r_brace, "}"),
        Token.new(.semicolon, ";"),

        Token.new(.let, "let"),
        Token.new(.ident, "result"),
        Token.new(.assign, "="),
        Token.new(.ident, "add"),
        Token.new(.l_paren, "("),
        Token.new(.ident, "five"),
        Token.new(.comma, ","),
        Token.new(.ident, "ten"),
        Token.new(.r_paren, ")"),
        Token.new(.semicolon, ";"),

        Token.new(.bang, "!"),
        Token.new(.minus, "-"),
        Token.new(.slash, "/"),
        Token.new(.asterisk, "*"),
        Token.new(.int, "5"),
        Token.new(.semicolon, ";"),

        Token.new(.int, "5"),
        Token.new(.lt, "<"),
        Token.new(.int, "10"),
        Token.new(.gt, ">"),
        Token.new(.int, "5"),
        Token.new(.semicolon, ";"),

        Token.new(._if, "if"),
        Token.new(.l_paren, "("),
        Token.new(.int, "5"),
        Token.new(.lt, "<"),
        Token.new(.int, "10"),
        Token.new(.r_paren, ")"),
        Token.new(.l_brace, "{"),
        Token.new(._return, "return"),
        Token.new(._true, "true"),
        Token.new(.semicolon, ";"),
        Token.new(.r_brace, "}"),
        Token.new(._else, "else"),
        Token.new(.l_brace, "{"),
        Token.new(._return, "return"),
        Token.new(._false, "false"),
        Token.new(.semicolon, ";"),
        Token.new(.r_brace, "}"),

        Token.new(.int, "10"),
        Token.new(.eq, "=="),
        Token.new(.int, "10"),
        Token.new(.semicolon, ";"),

        Token.new(.int, "10"),
        Token.new(.not_eq, "!="),
        Token.new(.int, "9"),
        Token.new(.semicolon, ";"),
        Token.new(.illegal, "@"),
        Token.new(.eof, ""),
    };

    var lexer = Lexer.init(input);

    for (expectations) |expected_token| {
        const current_token = lexer.nextToken();
        try expectEqual(expected_token.type, current_token.type);
        try expectEqualStrings(
            expected_token.literal,
            current_token.literal,
        );
    }
}
