const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ast = @import("ast.zig");
const Statement = ast.Statement;
const Program = ast.Program;
const LetStatement = ast.LetStatement;

const Self = @This();

lexer: *Lexer,
currentToken: Token,
peekToken: Token,
allocator: std.mem.Allocator,
errors: std.ArrayList(anyerror),

pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Self {
    return Self{
        .lexer = lexer,
        .currentToken = lexer.nextToken(),
        .peekToken = lexer.nextToken(),
        .allocator = allocator,
        .errors = std.ArrayList(anyerror).init(allocator),
    };
}

pub fn parseProgram(self: *Self) !Program {
    var statements = std.ArrayList(Statement).init(self.allocator);

    while (!self.currentTokenIs(.eof)) {
        try statements.append(try self.parseStatement());
        self.nextToken();
    }

    return Program{
        .statements = statements,
    };
}

fn nextToken(self: *Self) void {
    self.currentToken = self.peekToken;
    self.peekToken = self.lexer.nextToken();
}

fn expectPeek(self: *Self, tokenType: TokenType) !void {
    if (self.peekTokenIs(tokenType)) {
        self.nextToken();
        return;
    }

    switch (tokenType) {
        .ident => return error.ExpectedIdent,
        .assign => return error.ExpectedAssign,
        else => return error.UnexpectedToken,
    }
}

fn currentTokenIs(self: *Self, tokenType: TokenType) bool {
    return self.currentToken.type == tokenType;
}

fn peekTokenIs(self: *Self, tokenType: TokenType) bool {
    return self.peekToken.type == tokenType;
}

fn parseStatement(self: *Self) !Statement {
    switch (self.currentToken.type) {
        .let => return Statement{
            .let = try self.parseLetStatement(),
        },
        else => return error.NotImplemented,
    }
}

fn parseLetStatement(self: *Self) !LetStatement {
    const letToken = self.currentToken;

    try self.expectPeek(.ident);

    const ident = ast.Identifier{
        .token = self.currentToken,
        .value = self.currentToken.literal,
    };

    try self.expectPeek(.assign);

    self.nextToken();

    // TODO: Parse expression
    while (!self.currentTokenIs(.semicolon)) {
        self.nextToken();
    }

    return LetStatement{
        .token = letToken,
        .ident = ident,
        .value = null,
    };
}

test "let statements" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const expectEqualStrings = std.testing.expectEqualStrings;

    const input =
        \\let x = 5;
        \\let y = 10;
        \\let foobar = 838383;
    ;
    var lex = Lexer.init(input);
    var p = Self.init(&lex, allocator);
    const program = try p.parseProgram();

    try expect(program.statements.items.len == 3);

    const expectedIdents = [_][]const u8{
        "x",
        "y",
        "foobar",
    };

    for (expectedIdents, 0..) |_, i| {
        const s = program.statements.items[i];
        try expectEqualStrings("let", s.tokenLiteral());
        // try expect(@TypeOf(s.let.ident) == ast.Identifier);
        // try expectEqualStrings(name, s.let.ident.value);
    }
}
